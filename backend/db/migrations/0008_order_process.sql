-- 0008_order_process: six order states, expected delivery date, final fee
-- (data-model/06, ADR-0033), part 1 of 2: the status remap and the new columns.
-- Forward-only and NOT additive: stop the old backend, apply 0008 and 0009
-- together, start the new one. Take a custom format pg_dump first
-- (docs/engineering/db-backup.md); rollback is a restore.
-- Between the two files the status guard and capacity triggers are absent
-- (dropped below, recreated by 0009): never run the app on that state.
-- order_event rows and its append-only trigger are not touched: legacy words
-- stay in the history and are mapped when read.

-- Row count before the remap, kept for the verify block at the end. The
-- setting lives for this transaction only.
SELECT set_config('app.order_process_rows_before', (SELECT count(*) FROM customer_order)::text, true);

-- The remap must not write events (no real transition happens) and must not
-- be judged by the old transition pairs.
DROP TRIGGER customer_order_status_guard ON customer_order;
DROP TRIGGER customer_order_release_capacity ON customer_order;
ALTER TABLE customer_order DROP CONSTRAINT customer_order_status_check;
-- Stale predicate (New, Confirmed): replaced by the open list index below.
DROP INDEX customer_order_open_idx;

ALTER TABLE customer_order
    ADD COLUMN expected_delivery_date date,
    ADD COLUMN delivery_fee_final_vnd integer,
    ADD COLUMN delivery_fee_set_at timestamptz;

UPDATE customer_order
   SET status = CASE status
       WHEN 'New' THEN 'Received'
       WHEN 'Confirmed' THEN 'Processing'
       WHEN 'Completed' THEN 'Finished'
       ELSE status
   END
 WHERE status IN ('New', 'Confirmed', 'Completed');

-- The fee fixed at order time was the fee paid for orders already finished.
UPDATE customer_order
   SET delivery_fee_final_vnd = delivery_fee_vnd,
       delivery_fee_set_at = status_changed_at
 WHERE status = 'Finished';

ALTER TABLE customer_order
    ALTER COLUMN status SET DEFAULT 'Received',
    ADD CONSTRAINT customer_order_status_check CHECK (status IN (
        'Received', 'Processing', 'DeliveryDateScheduled', 'DeliveryStarted', 'Finished', 'Cancelled')),
    -- Legacy Finished rows may have no expected date.
    ADD CONSTRAINT customer_order_expected_date_required CHECK (
        status NOT IN ('DeliveryDateScheduled', 'DeliveryStarted') OR expected_delivery_date IS NOT NULL),
    ADD CONSTRAINT customer_order_fee_final_range CHECK (
        delivery_fee_final_vnd IS NULL OR delivery_fee_final_vnd BETWEEN 0 AND 10000000),
    ADD CONSTRAINT customer_order_fee_final_by_status CHECK (
        delivery_fee_final_vnd IS NULL OR status IN ('DeliveryStarted', 'Finished'));

-- Open list (order-process.md section 4): same expression as the query.
CREATE INDEX customer_order_open_list_idx ON customer_order (
    shop_id, (COALESCE(expected_delivery_date, delivery_date)), slot_start_time, created_at, id)
    WHERE status IN ('Received', 'Processing', 'DeliveryDateScheduled', 'DeliveryStarted');

-- Verify: nothing lost and no old word left. A failure aborts this file.
DO $$
BEGIN
    IF (SELECT count(*) FROM customer_order)::text <> current_setting('app.order_process_rows_before') THEN
        RAISE EXCEPTION 'customer_order row count changed during the remap';
    END IF;
    IF EXISTS (SELECT 1 FROM customer_order WHERE status IN ('New', 'Confirmed', 'Completed')) THEN
        RAISE EXCEPTION 'an old order status is left after the remap';
    END IF;
END;
$$;
