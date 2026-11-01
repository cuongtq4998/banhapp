package app.banh.admin.ui.cakes

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import app.banh.admin.R
import app.banh.admin.cakes.CakeBusy
import app.banh.admin.cakes.CakeDialog
import app.banh.admin.cakes.CakeField
import app.banh.admin.cakes.CakeFormState
import app.banh.admin.cakes.CakeIntent
import app.banh.admin.photo.ImageSource
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.forms.DiscardDialog
import app.banh.admin.ui.forms.problemText
import app.banh.core.design.Radii
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Spacing

private val PICTURE_HEIGHT = 200.dp

/** Add mode: the picture is required. Empty: one big tap target; chosen: the preview with "change" and "remove" text buttons. */
@Composable
fun PictureArea(state: CakeFormState, onPick: () -> Unit, dispatch: (CakeIntent) -> Unit) {
    val shape = RoundedCornerShape(Radii.image)
    val photo = state.photo
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        if (photo == null) {
            Box(
                Modifier.fillMaxWidth().height(PICTURE_HEIGHT).clip(shape).background(MaterialTheme.colorScheme.surfaceVariant)
                    .clickable(enabled = state.busy == CakeBusy.NONE, role = Role.Button, onClick = onPick).testTag(AdminTags.CAKE_FORM_IMAGE),
                Alignment.Center,
            ) { Text(stringResource(if (state.busy == CakeBusy.ENCODING) R.string.a_loading else R.string.a_img_pick), style = MaterialTheme.typography.titleMedium) }
        } else {
            val preview = remember(photo) { BitmapFactory.decodeByteArray(photo.jpeg, 0, photo.jpeg.size)?.asImageBitmap() }
            Box(Modifier.testTag(AdminTags.CAKE_FORM_IMAGE)) {
                preview?.let { Image(it, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxWidth().height(PICTURE_HEIGHT).clip(shape)) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                TextButton(onClick = onPick, enabled = state.busy == CakeBusy.NONE, modifier = Modifier.testTag(AdminTags.CAKE_FORM_CHANGE)) { Text(stringResource(R.string.a_img_change)) }
                TextButton(onClick = { dispatch(CakeIntent.RemovePhoto) }, enabled = state.busy == CakeBusy.NONE) { Text(stringResource(R.string.a_img_remove_pick)) }
            }
        }
        val problem = state.photoProblem ?: state.problems[CakeField.IMAGE]
        if (problem != null) Text(problemText(stringResource(R.string.a_img_pick), problem), color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag(AdminTags.cakeFormError(CakeField.IMAGE)))
    }
}

/** Edit mode: the stored picture, read-only, with the reason it cannot change. */
@Composable
fun EditPicture(state: CakeFormState, images: ImageSource) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        CakeImage(images, state.original?.imageUrl, PICTURE_HEIGHT, Modifier.fillMaxWidth().testTag(AdminTags.CAKE_FORM_IMAGE))
        Text(stringResource(R.string.a_img_not_editable), style = MaterialTheme.typography.bodySmall)
    }
}

/** Progress of the upload and the button that stops it; nothing is created when it stops (S-A8 Loading). */
@Composable
fun UploadBar(percent: Int, onCancel: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs), modifier = Modifier.testTag(AdminTags.CAKE_FORM_PROGRESS)) {
        Text(stringResource(R.string.a_uploading, percent), style = MaterialTheme.typography.bodyMedium)
        LinearProgressIndicator(progress = { percent / PERCENT }, modifier = Modifier.fillMaxWidth())
        SecondaryButton(stringResource(R.string.a_cancel_upload), onCancel, Modifier.testTag(AdminTags.CAKE_FORM_CANCEL))
    }
}

private const val PERCENT = 100f

/** The remove confirmation (Destructive, naming the cake) and the dirty-back dialog. */
@Composable
fun CakeDialogs(state: CakeFormState, dispatch: (CakeIntent) -> Unit, onLeave: () -> Unit) {
    when (state.dialog) {
        CakeDialog.REMOVE -> AlertDialog(
            onDismissRequest = { dispatch(CakeIntent.Dismiss) },
            title = { Text(stringResource(R.string.a_remove_title, state.original?.name.orEmpty())) },
            text = { Text(stringResource(R.string.a_remove_body)) },
            confirmButton = { TextButton(onClick = { dispatch(CakeIntent.RemoveYes) }, modifier = Modifier.testTag(AdminTags.CAKE_FORM_REMOVE_YES)) { Text(stringResource(R.string.a_remove_yes), color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { dispatch(CakeIntent.Dismiss) }) { Text(stringResource(R.string.a_back)) } },
        )
        CakeDialog.DISCARD -> DiscardDialog(onDiscard = onLeave, onKeep = { dispatch(CakeIntent.Dismiss) })
        CakeDialog.NONE -> Unit
    }
}
