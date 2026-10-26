package app.banh.customer.testing

/** The example response of docs/system/api.md 4.1 (fake sample values, list shortened). */
object SampleCatalogJson {
    const val BODY = """
{
  "server_date": "2026-11-02",
  "shop": { "name": "Tiệm Bánh Mẫu", "greeting": "Chào bạn, mời đặt bánh tét.", "phone_contact": "+84900000000", "zalo_contact": "84900000000" },
  "settings": { "min_qty": 2, "lead_days": 2, "max_days_ahead": 30, "max_qty_per_cake": 99, "note_max_length": 200 },
  "products": [
    { "product_id": "0b8f1f0e-1111-4a00-8000-000000000001", "slug": "banana", "name": "Bánh tét chuối", "description": "Mô tả mẫu.", "price_vnd": 50000, "image_url": "/assets/products/banana.jpg" }
  ],
  "districts": [ { "district_id": "0b8f1f0e-2222-4a00-8000-000000000001", "name": "Quận Mẫu 1", "delivery_fee_vnd": 20000 } ],
  "slots": [ { "slot_id": "0b8f1f0e-3333-4a00-8000-000000000001", "start": "08:00", "end": "10:00" } ]
}
"""
}
