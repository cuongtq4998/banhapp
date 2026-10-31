package app.banh.customer.data.network

import kotlinx.serialization.json.Json

/** One decoder for every API body; unknown response fields are ignored (api.md section 6). */
val ApiJson: Json = Json { ignoreUnknownKeys = true }
