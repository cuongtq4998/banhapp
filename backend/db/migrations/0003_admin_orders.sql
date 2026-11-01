-- 0003_admin_orders: cancel reason, order list indexes, text search
-- (docs/system/data-model/05-admin-orders-cakes-settings.md section 11,
-- ADR-0029, ADR-0030). Forward-only and additive: the previous release still
-- runs against it. The cake and settings changes of sections 12 and 13 belong
-- to a later slice and a later file.

-- Search fold (ADR-0029). `unaccent` is a trusted extension since PostgreSQL
-- 13; when the host refuses it, the documented fallback is plain lower(), so
-- diacritics must then match. One function, so the application never branches.
DO $$
BEGIN
    BEGIN
        CREATE EXTENSION IF NOT EXISTS unaccent;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'unaccent is not available; search falls back to lower()';
    END;
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'unaccent') THEN
        EXECUTE $body$CREATE FUNCTION search_fold(value text) RETURNS text
            LANGUAGE sql STABLE AS 'SELECT lower(unaccent(value))'$body$;
    ELSE
        EXECUTE $body$CREATE FUNCTION search_fold(value text) RETURNS text
            LANGUAGE sql IMMUTABLE AS 'SELECT lower(value)'$body$;
    END IF;
END;
$$;

-- No order can be Cancelled before the reason exists (the cancel path was
-- never exposed); stop instead of guessing a reason.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM customer_order WHERE status = 'Cancelled') THEN
        RAISE EXCEPTION 'Cancelled orders exist without a cancel reason; fix them before migrating';
    END IF;
END;
$$;

ALTER TABLE customer_order
    ADD COLUMN cancel_reason text,
    ADD COLUMN is_demo boolean NOT NULL DEFAULT false,
    ADD CONSTRAINT customer_order_cancel_reason_values CHECK (
        cancel_reason IN ('customer_asked', 'cannot_deliver', 'cannot_reach_customer', 'fake_spam')),
    ADD CONSTRAINT customer_order_cancel_reason_matches_status CHECK (
        (status = 'Cancelled') = (cancel_reason IS NOT NULL));

ALTER TABLE order_event
    ADD COLUMN reason text,
    ADD COLUMN actor_name text,
    ADD CONSTRAINT order_event_reason_values CHECK (
        reason IN ('customer_asked', 'cannot_deliver', 'cannot_reach_customer', 'fake_spam')),
    ADD CONSTRAINT order_event_reason_only_when_cancelled CHECK (reason IS NULL OR to_status = 'Cancelled'),
    ADD CONSTRAINT order_event_actor_fk FOREIGN KEY (actor_id) REFERENCES account (id) ON DELETE RESTRICT;

-- Finished orders of the 90-day window, and the open orders (a few dozen rows)
-- that serve the default list and the badge.
CREATE INDEX customer_order_shop_created_idx ON customer_order (shop_id, created_at);
CREATE INDEX customer_order_open_idx ON customer_order (shop_id, delivery_date)
    WHERE status IN ('New', 'Confirmed');

-- The event also takes the reason and the actor name set by the application
-- in the same transaction (app.actor_name). A cancellation returns the cakes
-- (a date with no load row is simply not touched).
CREATE OR REPLACE FUNCTION customer_order_release_capacity() RETURNS trigger
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
    INSERT INTO order_event (order_id, event_type, from_status, to_status, actor_type, actor_id, reason, actor_name)
    VALUES (
        NEW.id,
        'status_changed',
        OLD.status,
        NEW.status,
        COALESCE(NULLIF(current_setting('app.actor_type', true), ''), 'system'),
        NULLIF(current_setting('app.actor_id', true), '')::uuid,
        NEW.cancel_reason,
        NULLIF(current_setting('app.actor_name', true), '')
    );
    RETURN NEW;
END;
$$;

-- As in 0001, plus: a set cancel_reason cannot change or be cleared.
CREATE OR REPLACE FUNCTION customer_order_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    purging boolean := OLD.pii_purged_at IS NULL AND NEW.pii_purged_at IS NOT NULL;
BEGIN
    IF OLD.pii_purged_at IS NOT NULL AND NEW.pii_purged_at IS DISTINCT FROM OLD.pii_purged_at THEN
        RAISE EXCEPTION 'pii_purged_at cannot be changed once set' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.cancel_reason IS NOT NULL AND NEW.cancel_reason IS DISTINCT FROM OLD.cancel_reason THEN
        RAISE EXCEPTION 'cancel_reason cannot change once set' USING ERRCODE = 'check_violation';
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
