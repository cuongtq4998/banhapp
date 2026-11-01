-- 0004_admin_settings: the change record of the owner settings and the limits
-- of BR-11 (docs/system/data-model/04 section 3.16 and 05 section 13).
-- Forward-only and additive: the previous release only reads these columns and
-- never writes values outside the new ranges. The cake changes of data-model/05
-- section 12 belong to a later slice and a later file.

-- Append-only record of every owner change (BR-3). A save of one form shares a
-- batch_id; numbers and money are decimal text; account rows hold is_active only.
CREATE TABLE settings_change (
    id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id         uuid NOT NULL,
    shop_id          uuid NOT NULL REFERENCES shop (id) ON DELETE RESTRICT,
    actor_account_id uuid NOT NULL REFERENCES account (id) ON DELETE RESTRICT,
    actor_name       text NOT NULL,
    entity_type      text NOT NULL CHECK (entity_type IN ('shop', 'ordering', 'district', 'slot', 'cake', 'account')),
    entity_id        uuid,
    field            text NOT NULL,
    old_value        text,
    new_value        text,
    changed_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX settings_change_shop_changed ON settings_change (shop_id, changed_at);

CREATE FUNCTION settings_change_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'settings_change is append-only' USING ERRCODE = 'check_violation';
END;
$$;

CREATE TRIGGER settings_change_append_only
    BEFORE UPDATE OR DELETE ON settings_change
    FOR EACH ROW EXECUTE FUNCTION settings_change_append_only();

-- Upper bounds of BR-11; the lower bounds exist already or are checked by the
-- service. Existing rows (sample data, tests) are far inside the ranges.
ALTER TABLE shop_setting
    ADD CONSTRAINT shop_setting_daily_limit_max CHECK (daily_limit <= 9999),
    ADD CONSTRAINT shop_setting_lead_days_max CHECK (lead_days <= 14),
    ADD CONSTRAINT shop_setting_min_qty_max CHECK (min_qty <= 20),
    ADD CONSTRAINT shop_setting_min_qty_within_limit CHECK (min_qty <= daily_limit);

ALTER TABLE district
    ADD CONSTRAINT district_delivery_fee_max CHECK (delivery_fee_vnd <= 10000000);
