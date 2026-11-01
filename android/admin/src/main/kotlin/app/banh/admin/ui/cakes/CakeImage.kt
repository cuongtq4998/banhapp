package app.banh.admin.ui.cakes

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.banh.admin.R
import app.banh.admin.photo.ImageSource
import app.banh.core.design.Radii

/** A cake picture from the API, or the placeholder with icon and label when it did not load (`A_IMG_FAILED_A11Y`). */
@Composable
fun CakeImage(source: ImageSource, path: String?, size: Dp, modifier: Modifier = Modifier) {
    var bitmap by remember(path) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(path) { bitmap = path?.let { source.load(it, MAX_PX) } }
    val shape = RoundedCornerShape(Radii.image)
    val loaded = bitmap
    if (loaded != null) {
        Image(loaded, contentDescription = null, contentScale = ContentScale.Crop, modifier = modifier.size(size).clip(shape))
    } else {
        val label = stringResource(R.string.a_img_failed_a11y)
        Box(modifier.size(size).clip(shape).background(MaterialTheme.colorScheme.surfaceVariant).semantics { contentDescription = label }, Alignment.Center) {
            Icon(painterResource(R.drawable.ic_error), contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(24.dp))
        }
    }
}

private const val MAX_PX = 400
