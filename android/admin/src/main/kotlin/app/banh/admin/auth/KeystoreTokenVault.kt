package app.banh.admin.auth

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.serialization.json.Json

private const val KEYSTORE = "AndroidKeyStore"
private const val TRANSFORMATION = "AES/GCM/NoPadding"
private const val KEY_BITS = 256
private const val GCM_TAG_BITS = 128
private const val IV_BYTES = 12

/**
 * Stores [StoredSession] in an app-private file, encrypted with an AES-GCM key that never leaves the Android Keystore
 * (ADR-0022). Unreadable data (the key was lost after a restore or a screen-lock change) reads as "no session".
 */
class KeystoreTokenVault(private val file: File, private val alias: String = "banh_admin_session") : TokenVault {
    private val json = Json { ignoreUnknownKeys = true }

    @Synchronized
    override fun load(): StoredSession? = runCatching {
        val bytes = file.readBytes()
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(GCM_TAG_BITS, bytes.copyOfRange(0, IV_BYTES)))
        json.decodeFromString<StoredSession>(cipher.doFinal(bytes, IV_BYTES, bytes.size - IV_BYTES).decodeToString())
    }.getOrNull()

    @Synchronized
    override fun save(session: StoredSession) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val encrypted = cipher.iv + cipher.doFinal(json.encodeToString(StoredSession.serializer(), session).encodeToByteArray())
        // Written beside the target and renamed, so a crash never leaves a half-written token.
        val temporary = File(file.parentFile, file.name + ".tmp")
        temporary.writeBytes(encrypted)
        check(temporary.renameTo(file)) { "cannot replace the session file" }
    }

    @Synchronized
    override fun clear() {
        file.delete()
        runCatching { KeyStore.getInstance(KEYSTORE).apply { load(null) }.deleteEntry(alias) }
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        val spec = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(KEY_BITS)
            .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).apply { init(spec) }.generateKey()
    }
}
