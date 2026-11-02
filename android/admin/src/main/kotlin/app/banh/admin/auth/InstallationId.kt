package app.banh.admin.auth

import java.io.File
import java.util.UUID

/**
 * A random id per app install, sent at sign-in so the server can tell "new phone" from "same phone" (api/05 10.2).
 * It is not personal data and survives sign-out on purpose.
 */
fun interface InstallationId {
    fun get(): String
}

class FileInstallationId(private val file: File) : InstallationId {
    @Synchronized
    override fun get(): String {
        val existing = runCatching { file.readText().trim() }.getOrNull()
        if (!existing.isNullOrEmpty()) return existing
        return UUID.randomUUID().toString().also { file.writeText(it) }
    }
}
