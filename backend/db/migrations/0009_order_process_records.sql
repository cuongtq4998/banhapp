-- 0009_order_process_records: part 2 of 2 of data-model/06 (ADR-0033). Needs
-- 0008. Adds the date and fee record tables and recreates the guard,
-- capacity and immutable triggers for the six states. Same backup and
-- stop-the-backend rule as 0008.

CREATE TABLE order_expected_date_change (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id              uuid NOT NULL REFERENCES customer_order (id) ON DELETE RESTRICT,
    old_date              date,
    new_date              date NOT NULL,
    changed_by_account_id uuid REFERENCES account (id) ON DELETE SET NULL,
    changed_by_name       text NOT NULL,
    changed_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX order_expected_date_change_order_idx ON order_expected_date_change (order_id, id);

CREATE TABLE order_fee_correction (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id              uuid NOT NULL REFERENCES customer_order (id) ON DELETE RESTRICT,
    old_fee_vnd           integer NOT NULL CHECK (old_fee_vnd BETWEEN 0 AND 10000000),
    new_fee_vnd           integer NOT NULL CHECK (new_fee_vnd BETWEEN 0 AND 10000000),
    changed_by_account_id uuid REFERENCES account (id) ON DELETE SET NULL,
    changed_by_name       text NOT NULL,
    changed_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT order_fee_correction_changed CHECK (new_fee_vnd <> old_fee_vnd)
);
CREATE INDEX order_fee_correction_order_idx ON order_fee_correction (order_id, id);

-- Records never change. The one allowed update is the ON DELETE SET NULL of
-- a removed account (the name stays), so every other column must be equal.
CREATE FUNCTION order_record_insert_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.changed_by_account_id IS NULL
       AND (to_jsonb(NEW) - 'changed_by_account_id') = (to_jsonb(OLD) - 'changed_by_account_id')
    THEN
        RETURN NEW;
    END IF;
    RAISE EXCEPTION '% is insert-only', TG_TABLE_NAME USING ERRCODE = 'check_violation';
END;
$$;

CREATE TRIGGER order_expected_date_change_insert_only
    BEFORE UPDATE OR DELETE ON order_expected_date_change
    FOR EACH ROW EXECUTE FUNCTION order_record_insert_only();
CREATE TRIGGER order_fee_correction_insert_only
    BEFORE UPDATE OR DELETE ON order_fee_correction
    FOR EACH ROW EXECUTE FUNCTION order_record_insert_only();

-- Pairs of order-process.md section 2. An unchanged status passes.
CREATE OR REPLACE FUNCTION customer_order_status_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;
    IF (OLD.status, NEW.status) NOT IN (
        ('Received', 'Processing'),
        ('Received', 'Cancelled'),
        ('Processing', 'DeliveryDateScheduled'),
        ('Processing', 'Cancelled'),
        ('DeliveryDateScheduled', 'DeliveryStarted'),
        ('DeliveryStarted', 'Finished')
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

-- As in 0005: only a cancellation of a real order returns cakes; every
-- status change writes one event with the new words.
CREATE OR REPLACE FUNCTION customer_order_release_capacity() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;
    IF NEW.status = 'Cancelled' AND NOT OLD.is_demo THEN
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

CREATE TRIGGER customer_order_release_capacity
    AFTER UPDATE OF status ON customer_order
    FOR EACH ROW EXECUTE FUNCTION customer_order_release_capacity();

-- As in 0003, plus the rules of data-model/06 section 6: expected date, final
-- fee and its time are mutable; the fee changes only on first entry or as a
-- correction in DeliveryStarted; nothing of them changes after a final state.
CREATE OR REPLACE FUNCTION customer_order_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    purging boolean := OLD.pii_purged_at IS NULL AND NEW.pii_purged_at IS NOT NULL;
    fee_first_entry boolean := OLD.status = 'DeliveryDateScheduled' AND NEW.status = 'DeliveryStarted';
    fee_correction boolean := OLD.status = 'DeliveryStarted' AND NEW.status = 'DeliveryStarted'
                              AND OLD.delivery_fee_final_vnd IS NOT NULL;
BEGIN
    IF OLD.pii_purged_at IS NOT NULL AND NEW.pii_purged_at IS DISTINCT FROM OLD.pii_purged_at THEN
        RAISE EXCEPTION 'pii_purged_at cannot be changed once set' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.cancel_reason IS NOT NULL AND NEW.cancel_reason IS DISTINCT FROM OLD.cancel_reason THEN
        RAISE EXCEPTION 'cancel_reason cannot change once set' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.status IN ('Finished', 'Cancelled')
       AND (NEW.delivery_fee_final_vnd, NEW.expected_delivery_date)
           IS DISTINCT FROM (OLD.delivery_fee_final_vnd, OLD.expected_delivery_date)
    THEN
        RAISE EXCEPTION 'fee and expected date are fixed once the order is final' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.delivery_fee_final_vnd IS DISTINCT FROM OLD.delivery_fee_final_vnd
       AND NOT (fee_first_entry OR fee_correction)
    THEN
        RAISE EXCEPTION 'final fee changes only on entry or as a correction' USING ERRCODE = 'check_violation';
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

-- Verify: new objects present. A failure aborts this file.
DO $$
BEGIN
    IF (SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal AND tgname IN (
            'order_expected_date_change_insert_only', 'order_fee_correction_insert_only',
            'customer_order_status_guard', 'customer_order_release_capacity')) <> 4 THEN
        RAISE EXCEPTION 'order process triggers are missing';
    END IF;
    IF (SELECT count(*) FROM pg_constraint WHERE conrelid = 'order_fee_correction'::regclass AND contype = 'c') < 3 THEN
        RAISE EXCEPTION 'order_fee_correction checks are missing';
    END IF;
END;
$$;
