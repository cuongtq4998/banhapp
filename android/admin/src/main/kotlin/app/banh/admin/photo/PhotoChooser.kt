package app.banh.admin.photo

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberUpdatedState

/** Opens the place where the owner picks a picture. [rememberPicker] returns the function that opens it; the result comes back as text (a URI), or null when cancelled. */
interface PhotoChooser {
    @Composable
    fun rememberPicker(onPicked: (String?) -> Unit): () -> Unit
}

/** The system photo picker: no permission and no prompt (design part 7; the picker returns only what the person selects). */
object SystemPhotoChooser : PhotoChooser {
    @Composable
    override fun rememberPicker(onPicked: (String?) -> Unit): () -> Unit {
        val latest = rememberUpdatedState(onPicked)
        val launcher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { latest.value(it?.toString()) }
        return { launcher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
    }
}
