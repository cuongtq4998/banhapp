-- 0007_security_event_purge: the maintenance purge must be able to remove
-- security events after 180 days (MaintenancePolicy.securityEventAge), but
-- 0002 refuses every DELETE. Events older than that now move to
-- security_event_archive in one statement; a younger row can never be deleted.
-- The archive holds only ids, a timestamp and enums: no address, no phone, no
-- IP address, no name. Forward-only: the previous release never deletes events.

CREATE OR REPLACE FUNCTION security_event_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    -- 180 days equals MaintenancePolicy.standard.securityEventAge (tested).
    IF TG_OP = 'DELETE' AND OLD.at < now() - interval '180 days' THEN
        RETURN OLD;
    END IF;
    RAISE EXCEPTION 'security_event is append-only' USING ERRCODE = 'check_violation';
END;
$$;

-- No foreign key: an archived row must outlive any later change to account.
CREATE TABLE security_event_archive (
    id                bigint PRIMARY KEY,
    at                timestamptz NOT NULL,
    event_type        text NOT NULL,
    account_id        uuid,
    device_session_id uuid,
    platform          text,
    archived_at       timestamptz NOT NULL DEFAULT now()
);

CREATE FUNCTION security_event_archive_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'security_event_archive is append-only' USING ERRCODE = 'check_violation';
END;
$$;

CREATE TRIGGER security_event_archive_append_only
    BEFORE UPDATE OR DELETE ON security_event_archive
    FOR EACH ROW EXECUTE FUNCTION security_event_archive_append_only();
