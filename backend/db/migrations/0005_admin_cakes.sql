-- 0005_admin_cakes: cakes the owner adds, hides and removes, their images
-- stored in the database (data-model/05 section 12, ADR-0025, ADR-0031), and
-- the fix of defect D-2 (demo orders never touch day_load).
-- Forward-only and additive: the previous release reads the same columns, the
-- sample cakes keep image_source 'file' and their image_path.

ALTER TABLE product
    ALTER COLUMN image_path DROP NOT NULL,
    ADD COLUMN image_source text NOT NULL DEFAULT 'file',
    ADD COLUMN removed_at timestamptz,
    ADD CONSTRAINT product_image_source_valid CHECK (image_source IN ('file', 'upload')),
    ADD CONSTRAINT product_image_path_for_file CHECK (image_source = 'upload' OR image_path IS NOT NULL),
    ADD CONSTRAINT product_removed_is_inactive CHECK (removed_at IS NULL OR is_active = false),
    ADD CONSTRAINT product_price_max CHECK (price_vnd <= 100000000);

-- A name is free again once its cake is removed; letter case does not count.
CREATE UNIQUE INDEX product_shop_name_live ON product (shop_id, lower(name)) WHERE removed_at IS NULL;

CREATE TABLE product_image (
    product_id   uuid PRIMARY KEY REFERENCES product (id) ON DELETE RESTRICT,
    content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png')),
    bytes        bytea NOT NULL CHECK (octet_length(bytes) BETWEEN 1 AND 5242880),
    width        integer NOT NULL CHECK (width BETWEEN 200 AND 4096),
    height       integer NOT NULL CHECK (height BETWEEN 200 AND 4096),
    sha256       text NOT NULL CHECK (char_length(sha256) = 64),
    created_at   timestamptz NOT NULL DEFAULT now()
);

-- At most 12 cakes that are not removed. The shop_setting row lock makes two
-- concurrent inserts count one after the other; the service checks first and
-- answers CAKE_LIMIT_REACHED, this is the last line of defence.
CREATE FUNCTION product_cap_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND (NEW.removed_at IS NOT NULL OR OLD.removed_at IS NULL) THEN
        RETURN NEW;
    END IF;
    PERFORM 1 FROM shop_setting WHERE shop_id = NEW.shop_id FOR UPDATE;
    IF (SELECT count(*) FROM product WHERE shop_id = NEW.shop_id AND removed_at IS NULL AND id <> NEW.id) >= 12 THEN
        RAISE EXCEPTION 'a shop has at most 12 cakes that are not removed' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER product_cap_guard
    BEFORE INSERT OR UPDATE OF removed_at ON product
    FOR EACH ROW EXECUTE FUNCTION product_cap_guard();

-- D-2: as in 0003, but a demo order (ADR-0027) is not part of day_load, so its
-- cancellation gives no cakes back.
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
