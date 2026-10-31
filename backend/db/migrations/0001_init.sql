-- 0001_init: initial schema (docs/system/data-model.md sections 3 to 5).
-- Forward-only. Uses only features available from PostgreSQL 14.
-- Triggers and functions use dollar quoting; the migration runner splits the
-- file with a scanner that understands it (Sources/App/Migrations).

CREATE TABLE shop (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name          text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
    greeting      text NOT NULL CHECK (char_length(greeting) BETWEEN 1 AND 300),
    phone_contact text NOT NULL CHECK (phone_contact ~ '^\+[1-9][0-9]{7,14}$'),
    zalo_contact  text NOT NULL CHECK (char_length(zalo_contact) BETWEEN 3 AND 100),
    timezone      text NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
    is_sample     boolean NOT NULL DEFAULT false,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE shop_setting (
    shop_id          uuid PRIMARY KEY REFERENCES shop (id) ON DELETE RESTRICT,
    daily_limit      integer NOT NULL CHECK (daily_limit > 0),
    lead_days        integer NOT NULL DEFAULT 2 CHECK (lead_days >= 0),
    min_qty          integer NOT NULL DEFAULT 2 CHECK (min_qty >= 1),
    max_days_ahead   integer NOT NULL DEFAULT 30,
    max_qty_per_cake integer NOT NULL DEFAULT 99 CHECK (max_qty_per_cake BETWEEN 1 AND 99),
    is_sample        boolean NOT NULL DEFAULT false,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT shop_setting_horizon_after_lead CHECK (max_days_ahead >= lead_days)
);

CREATE TABLE product (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id     uuid NOT NULL REFERENCES shop (id) ON DELETE RESTRICT,
    slug        text NOT NULL CHECK (slug ~ '^[a-z0-9-]{1,40}$'),
    name        text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
    description text NOT NULL CHECK (char_length(description) BETWEEN 1 AND 300),
    price_vnd   integer NOT NULL CHECK (price_vnd >= 0),
    image_path  text NOT NULL,
    sort_order  integer NOT NULL DEFAULT 0,
    is_active   boolean NOT NULL DEFAULT true,
    is_sample   boolean NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_shop_slug_unique UNIQUE (shop_id, slug)
);

CREATE TABLE district (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id          uuid NOT NULL REFERENCES shop (id) ON DELETE RESTRICT,
    name             text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
    delivery_fee_vnd integer NOT NULL CHECK (delivery_fee_vnd >= 0),
    sort_order       integer NOT NULL DEFAULT 0,
    is_active        boolean NOT NULL DEFAULT true,
    is_sample        boolean NOT NULL DEFAULT false,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT district_shop_name_unique UNIQUE (shop_id, name)
);

CREATE TABLE delivery_slot (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id    uuid NOT NULL REFERENCES shop (id) ON DELETE RESTRICT,
    start_time time NOT NULL,
    end_time   time NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active  boolean NOT NULL DEFAULT true,
    is_sample  boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT delivery_slot_end_after_start CHECK (end_time > start_time),
    CONSTRAINT delivery_slot_shop_times_unique UNIQUE (shop_id, start_time, end_time)
);

-- The single point where the daily limit is enforced (ADR-0008): the primary
-- key gives one counter per date, and the CHECK stops faulty code from
-- exceeding the limit.
CREATE TABLE day_load (
    shop_id        uuid NOT NULL REFERENCES shop (id) ON DELETE RESTRICT,
    delivery_date  date NOT NULL,
    cakes_accepted integer NOT NULL DEFAULT 0,
    capacity_limit integer NOT NULL CHECK (capacity_limit > 0),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (shop_id, delivery_date),
    CONSTRAINT day_load_within_limit CHECK (cakes_accepted >= 0 AND cakes_accepted <= capacity_limit)
);

CREATE TABLE customer_order (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id            uuid NOT NULL REFERENCES shop (id) ON DELETE RESTRICT,
    order_code         text NOT NULL CHECK (order_code ~ '^BT-[2-9A-HJKMNP-Z]{6}$'),
    status             text NOT NULL DEFAULT 'New'
                       CHECK (status IN ('New', 'Confirmed', 'Completed', 'Cancelled')),
    payment_status     text NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid')),
    delivery_date      date NOT NULL,
    slot_id            uuid NOT NULL REFERENCES delivery_slot (id) ON DELETE RESTRICT,
    slot_start_time    time NOT NULL,
    slot_end_time      time NOT NULL,
    district_id        uuid NOT NULL REFERENCES district (id) ON DELETE RESTRICT,
    district_name      text NOT NULL,
    delivery_fee_vnd   integer NOT NULL CHECK (delivery_fee_vnd >= 0),
    items_subtotal_vnd integer NOT NULL CHECK (items_subtotal_vnd >= 0),
    total_vnd          integer NOT NULL CHECK (total_vnd >= 0),
    total_cakes        integer NOT NULL CHECK (total_cakes >= 1),
    customer_name      text NOT NULL,
    customer_phone     text NOT NULL,
    customer_address   text NOT NULL,
    note               text CHECK (note IS NULL OR char_length(note) <= 200),
    idempotency_key    uuid NOT NULL,
    request_hash       text NOT NULL CHECK (char_length(request_hash) = 64),
    client_platform    text NOT NULL CHECK (client_platform IN ('ios', 'android')),
    app_version        text NOT NULL CHECK (char_length(app_version) BETWEEN 1 AND 20),
    status_changed_at  timestamptz NOT NULL DEFAULT now(),
    pii_purged_at      timestamptz,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT customer_order_code_unique UNIQUE (order_code),
    CONSTRAINT customer_order_idempotency_unique UNIQUE (shop_id, idempotency_key),
    CONSTRAINT customer_order_total_is_sum CHECK (total_vnd = items_subtotal_vnd + delivery_fee_vnd),
    -- A purge blanks the personal columns, so their format checks only apply
    -- while the row has not been purged (data-model.md 3.7).
    CONSTRAINT customer_order_name_valid CHECK (
        pii_purged_at IS NOT NULL OR char_length(customer_name) BETWEEN 1 AND 100),
    CONSTRAINT customer_order_phone_valid CHECK (
        pii_purged_at IS NOT NULL OR customer_phone ~ '^\+84[35789][0-9]{8}$'),
    CONSTRAINT customer_order_address_valid CHECK (
        pii_purged_at IS NOT NULL OR char_length(customer_address) BETWEEN 1 AND 250)
);

CREATE TABLE customer_order_item (
    order_id       uuid NOT NULL REFERENCES customer_order (id) ON DELETE RESTRICT,
    product_id     uuid NOT NULL REFERENCES product (id) ON DELETE RESTRICT,
    product_name   text NOT NULL,
    unit_price_vnd integer NOT NULL CHECK (unit_price_vnd >= 0),
    quantity       integer NOT NULL CHECK (quantity BETWEEN 1 AND 99),
    line_total_vnd integer NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT customer_order_item_line_total CHECK (line_total_vnd = unit_price_vnd * quantity)
);

CREATE TABLE order_event (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    uuid NOT NULL REFERENCES customer_order (id) ON DELETE RESTRICT,
    event_type  text NOT NULL CHECK (event_type IN ('created', 'status_changed')),
    from_status text,
    to_status   text NOT NULL,
    actor_type  text NOT NULL CHECK (actor_type IN ('customer', 'staff', 'owner', 'system')),
    actor_id    uuid,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Indexes beyond the primary and unique keys above (data-model.md section 5).
CREATE INDEX customer_order_shop_date_status_idx ON customer_order (shop_id, delivery_date, status);
CREATE INDEX customer_order_phone_created_idx ON customer_order (customer_phone, created_at);
CREATE INDEX customer_order_shop_status_created_idx ON customer_order (shop_id, status, created_at);
CREATE INDEX order_event_order_idx ON order_event (order_id);

-- customer_order_status_guard: only the transitions of order-lifecycle.md
-- section 6 are possible, even for direct SQL. An update that leaves the
-- status unchanged is allowed.
CREATE FUNCTION customer_order_status_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;
    IF (OLD.status, NEW.status) NOT IN (
        ('New', 'Confirmed'),
        ('New', 'Cancelled'),
        ('Confirmed', 'Completed'),
        ('Confirmed', 'Cancelled')
    ) THEN
        RAISE EXCEPTION 'invalid order status transition % -> %', OLD.status, NEW.status
            USING ERRCODE = 'check_violation';
    END IF;
    NEW.status_changed_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER customer_order_status_guard
    BEFORE UPDATE OF status ON customer_order
    FOR EACH ROW EXECUTE FUNCTION customer_order_status_guard();

-- customer_order_release_capacity: every status change is recorded in
-- order_event; a cancellation also returns the cakes to the date (BR-9).
-- The actor defaults to 'system'; a later staff endpoint can set the session
-- settings app.actor_type and app.actor_id in the same transaction so one
-- event is written with the right actor.
CREATE FUNCTION customer_order_release_capacity() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;
    IF NEW.status = 'Cancelled' THEN
        UPDATE day_load
           SET cakes_accepted = cakes_accepted - OLD.total_cakes,
               updated_at = now()
         WHERE shop_id = OLD.shop_id AND delivery_date = OLD.delivery_date;
    END IF;
    INSERT INTO order_event (order_id, event_type, from_status, to_status, actor_type, actor_id)
    VALUES (
        NEW.id,
        'status_changed',
        OLD.status,
        NEW.status,
        COALESCE(NULLIF(current_setting('app.actor_type', true), ''), 'system'),
        NULLIF(current_setting('app.actor_id', true), '')::uuid
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER customer_order_release_capacity
    AFTER UPDATE OF status ON customer_order
    FOR EACH ROW EXECUTE FUNCTION customer_order_release_capacity();

-- customer_order_immutable: snapshots never change (BR-6). Mutable: status
-- (guarded above), payment_status, status_changed_at, updated_at and
-- pii_purged_at. The personal columns may change only in the update that
-- first sets pii_purged_at.
CREATE FUNCTION customer_order_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    purging boolean := OLD.pii_purged_at IS NULL AND NEW.pii_purged_at IS NOT NULL;
BEGIN
    IF OLD.pii_purged_at IS NOT NULL AND NEW.pii_purged_at IS DISTINCT FROM OLD.pii_purged_at THEN
        RAISE EXCEPTION 'pii_purged_at cannot be changed once set' USING ERRCODE = 'check_violation';
    END IF;
    IF (NEW.id, NEW.shop_id, NEW.order_code, NEW.delivery_date, NEW.slot_id,
        NEW.slot_start_time, NEW.slot_end_time, NEW.district_id, NEW.district_name,
        NEW.delivery_fee_vnd, NEW.items_subtotal_vnd, NEW.total_vnd, NEW.total_cakes,
        NEW.idempotency_key, NEW.request_hash, NEW.client_platform, NEW.app_version,
        NEW.created_at)
       IS DISTINCT FROM
       (OLD.id, OLD.shop_id, OLD.order_code, OLD.delivery_date, OLD.slot_id,
        OLD.slot_start_time, OLD.slot_end_time, OLD.district_id, OLD.district_name,
        OLD.delivery_fee_vnd, OLD.items_subtotal_vnd, OLD.total_vnd, OLD.total_cakes,
        OLD.idempotency_key, OLD.request_hash, OLD.client_platform, OLD.app_version,
        OLD.created_at)
    THEN
        RAISE EXCEPTION 'order snapshot columns are immutable' USING ERRCODE = 'check_violation';
    END IF;
    IF NOT purging
       AND (NEW.customer_name, NEW.customer_phone, NEW.customer_address, NEW.note)
           IS DISTINCT FROM
           (OLD.customer_name, OLD.customer_phone, OLD.customer_address, OLD.note)
    THEN
        RAISE EXCEPTION 'personal columns change only when pii_purged_at is set' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER customer_order_immutable
    BEFORE UPDATE ON customer_order
    FOR EACH ROW EXECUTE FUNCTION customer_order_immutable();

-- order_event is an append-only audit trail.
CREATE FUNCTION order_event_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'order_event is append-only' USING ERRCODE = 'check_violation';
END;
$$;

CREATE TRIGGER order_event_append_only
    BEFORE UPDATE OR DELETE ON order_event
    FOR EACH ROW EXECUTE FUNCTION order_event_append_only();
