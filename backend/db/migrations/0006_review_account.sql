-- 0006_review_account: the operator command `review-account off` removes the
-- demo orders of the store-review account (ADR-0027) and, with them, their
-- history. order_event stays append-only for every real order; only the rows
-- of an order flagged is_demo may be deleted (never updated).
-- Forward-only and additive: the previous release does not delete events.

CREATE OR REPLACE FUNCTION order_event_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE'
       AND EXISTS (SELECT 1 FROM customer_order WHERE id = OLD.order_id AND is_demo) THEN
        RETURN OLD;
    END IF;
    RAISE EXCEPTION 'order_event is append-only' USING ERRCODE = 'check_violation';
END;
$$;
