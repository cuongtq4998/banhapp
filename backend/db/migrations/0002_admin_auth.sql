-- 0002_admin_auth: admin accounts, sign-in codes, device sessions, security
-- events (docs/system/data-model/04-admin-accounts-sessions.md, sections 3.10
-- to 3.15). Forward-only. Same conventions as 0001 (dollar-quoted functions).

CREATE TABLE account (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id        uuid NOT NULL REFERENCES shop (id) ON DELETE RESTRICT,
    role           text NOT NULL CHECK (role IN ('owner', 'staff')),
    kind           text NOT NULL DEFAULT 'normal' CHECK (kind IN ('normal', 'review')),
    email          text NOT NULL CHECK (char_length(email) BETWEEN 3 AND 254),
    display_name   text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 100),
    is_active      boolean NOT NULL DEFAULT true,
    deactivated_at timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT account_shop_email_unique UNIQUE (shop_id, email),
    CONSTRAINT account_owner_stays_active CHECK (role <> 'owner' OR is_active)
);

-- Exactly one owner per shop.
CREATE UNIQUE INDEX account_one_owner ON account (shop_id) WHERE role = 'owner';

-- BR-6: at most 30 active staff. The shop_setting row is locked first, so two
-- concurrent additions are counted one after the other. Review accounts do
-- not count.
CREATE FUNCTION account_staff_limit() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.role = 'staff' AND NEW.kind = 'normal' AND NEW.is_active
       AND (TG_OP = 'INSERT' OR NOT OLD.is_active) THEN
        PERFORM 1 FROM shop_setting WHERE shop_id = NEW.shop_id FOR UPDATE;
        IF (SELECT count(*) FROM account
             WHERE shop_id = NEW.shop_id AND role = 'staff' AND kind = 'normal'
               AND is_active AND id <> NEW.id) >= 30 THEN
            RAISE EXCEPTION 'staff limit reached' USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER account_staff_limit
    BEFORE INSERT OR UPDATE ON account
    FOR EACH ROW EXECUTE FUNCTION account_staff_limit();

-- One row per signed-in phone and its credential family.
CREATE TABLE device_session (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id            uuid NOT NULL REFERENCES account (id) ON DELETE RESTRICT,
    installation_id       uuid NOT NULL,
    platform              text NOT NULL CHECK (platform IN ('ios', 'android')),
    device_name           text NOT NULL CHECK (char_length(device_name) BETWEEN 1 AND 60),
    push_token            text UNIQUE CHECK (char_length(push_token) BETWEEN 1 AND 512),
    push_apns_environment text CHECK (push_apns_environment IN ('production', 'sandbox')),
    sign_in_method        text NOT NULL CHECK (sign_in_method IN ('code', 'review')),
    access_token_hash     bytea NOT NULL CHECK (octet_length(access_token_hash) = 32),
    access_expires_at     timestamptz NOT NULL,
    refresh_token_hash    bytea NOT NULL CHECK (octet_length(refresh_token_hash) = 32),
    previous_refresh_hash bytea CHECK (octet_length(previous_refresh_hash) = 32),
    refresh_rotated_at    timestamptz,
    refresh_expires_at    timestamptz NOT NULL,
    last_used_at          timestamptz NOT NULL DEFAULT now(),
    revoked_at            timestamptz,
    revoked_reason        text CHECK (revoked_reason IN (
        'signed_out', 'signed_out_others', 'account_deactivated',
        'reuse_detected', 'replaced', 'expired_cleanup')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT device_session_revoked_pair CHECK ((revoked_at IS NULL) = (revoked_reason IS NULL)),
    CONSTRAINT device_session_apns_environment CHECK (
        push_token IS NULL OR platform <> 'ios' OR push_apns_environment IS NOT NULL)
);

CREATE INDEX device_session_live_by_account ON device_session (account_id) WHERE revoked_at IS NULL;
CREATE INDEX device_session_installation ON device_session (installation_id);
CREATE INDEX device_session_revoked_at ON device_session (revoked_at);

-- One-time sign-in codes. Unregistered addresses get a row too (account_id
-- null, random hash), so limits and answers do not show who is registered.
CREATE TABLE auth_code (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email        text NOT NULL CHECK (char_length(email) BETWEEN 3 AND 254),
    account_id   uuid REFERENCES account (id) ON DELETE RESTRICT,
    code_hmac    bytea NOT NULL CHECK (octet_length(code_hmac) = 32),
    created_at   timestamptz NOT NULL DEFAULT now(),
    expires_at   timestamptz NOT NULL,
    consumed_at  timestamptz,
    mail_sent_at timestamptz,
    wrong_count  smallint NOT NULL DEFAULT 0 CHECK (wrong_count BETWEEN 0 AND 5)
);

CREATE INDEX auth_code_email_created ON auth_code (email, created_at DESC);
CREATE INDEX auth_code_created ON auth_code (created_at);

-- Audit of access (not of orders). No e-mail address and no code.
CREATE TABLE security_event (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    at                timestamptz NOT NULL DEFAULT now(),
    event_type        text NOT NULL CHECK (event_type IN (
        'sign_in', 'sign_in_review', 'sign_out', 'sign_out_others', 'refresh_reuse_detected')),
    account_id        uuid REFERENCES account (id) ON DELETE RESTRICT,
    device_session_id uuid,
    platform          text CHECK (platform IN ('ios', 'android'))
);

CREATE FUNCTION security_event_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'security_event is append-only' USING ERRCODE = 'check_violation';
END;
$$;

CREATE TRIGGER security_event_append_only
    BEFORE UPDATE OR DELETE ON security_event
    FOR EACH ROW EXECUTE FUNCTION security_event_append_only();
