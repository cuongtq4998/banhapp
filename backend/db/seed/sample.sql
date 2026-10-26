-- Sample shop data for local and staging (ADR-0013, AC-29).
-- Every row is fake and marked is_sample = true; the API never exposes the flag.
-- Fixed identifiers let SHOP_ID and the fixtures refer to the same rows.
-- Idempotent: safe to run more than once. Real values arrive through a
-- reviewed change that sets is_sample = false.

INSERT INTO shop (id, name, greeting, phone_contact, zalo_contact, is_sample)
VALUES (
    '00000000-0000-4000-8000-000000000001',
    'Tiệm bánh Hoa Sen',
    'Bánh làm thủ công, giao tận nơi.',
    '+84123456789',
    '84123456789',
    true
) ON CONFLICT (id) DO NOTHING;

INSERT INTO shop_setting (shop_id, daily_limit, lead_days, min_qty, max_days_ahead, max_qty_per_cake, is_sample)
VALUES ('00000000-0000-4000-8000-000000000001', 30, 2, 2, 30, 99, true)
ON CONFLICT (shop_id) DO NOTHING;

INSERT INTO product (id, shop_id, slug, name, description, price_vnd, image_path, sort_order, is_sample)
VALUES
    ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001',
     'banana', 'Bánh chuối', 'Bánh chuối nướng thơm béo.', 35000, 'images/banana.png', 1, true),
    ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000001',
     'mung-bean-pork-fat', 'Bánh đậu xanh nhân mỡ', 'Đậu xanh nghiền mịn, nhân mỡ.', 45000, 'images/mung-bean-pork-fat.png', 2, true),
    ('00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000001',
     'mung-bean-vegetarian', 'Bánh đậu xanh chay', 'Đậu xanh nghiền mịn, không nhân mỡ.', 45000, 'images/mung-bean-vegetarian.png', 3, true),
    ('00000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000001',
     'mung-bean-egg-yolk-pork-fat', 'Bánh đậu xanh trứng mỡ', 'Đậu xanh, trứng muối và mỡ.', 55000, 'images/mung-bean-egg-yolk-pork-fat.png', 4, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO district (id, shop_id, name, delivery_fee_vnd, sort_order, is_sample)
VALUES
    ('00000000-0000-4000-8000-000000000021', '00000000-0000-4000-8000-000000000001', 'Quận 1', 15000, 1, true),
    ('00000000-0000-4000-8000-000000000022', '00000000-0000-4000-8000-000000000001', 'Quận 3', 15000, 2, true),
    ('00000000-0000-4000-8000-000000000023', '00000000-0000-4000-8000-000000000001', 'Quận 5', 20000, 3, true),
    ('00000000-0000-4000-8000-000000000024', '00000000-0000-4000-8000-000000000001', 'Phú Nhuận', 20000, 4, true),
    ('00000000-0000-4000-8000-000000000025', '00000000-0000-4000-8000-000000000001', 'Bình Thạnh', 25000, 5, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO delivery_slot (id, shop_id, start_time, end_time, sort_order, is_sample)
VALUES
    ('00000000-0000-4000-8000-000000000031', '00000000-0000-4000-8000-000000000001', '08:00', '10:00', 1, true),
    ('00000000-0000-4000-8000-000000000032', '00000000-0000-4000-8000-000000000001', '10:00', '12:00', 2, true),
    ('00000000-0000-4000-8000-000000000033', '00000000-0000-4000-8000-000000000001', '14:00', '16:00', 3, true),
    ('00000000-0000-4000-8000-000000000034', '00000000-0000-4000-8000-000000000001', '16:00', '18:00', 4, true)
ON CONFLICT (id) DO NOTHING;
