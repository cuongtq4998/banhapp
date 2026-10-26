package app.banh.customer.ui.common

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.design.Radii
import app.banh.customer.design.SkeletonBlock

/** Provided once at the root so product pictures do not need the loader passed through every screen. */
val LocalImageLoader = compositionLocalOf<ImageLoader> { error("No ImageLoader provided") }

private sealed interface ImageState {
    data object Loading : ImageState

    data class Loaded(val bitmap: ImageBitmap) : ImageState

    data object Failed : ImageState
}

/** A cake picture with a skeleton while loading and a placeholder icon when it cannot be shown (UI document 5.3). */
@Composable
fun ProductImage(path: String, name: String, modifier: Modifier = Modifier) {
    val loader = LocalImageLoader.current
    BoxWithConstraints(modifier = modifier.clip(RoundedCornerShape(Radii.image))) {
        val targetWidthPx = constraints.maxWidth
        val state: State<ImageState> = produceState<ImageState>(ImageState.Loading, path, targetWidthPx) {
            val bitmap = loader.load(path, targetWidthPx)
            value = if (bitmap != null) ImageState.Loaded(bitmap) else ImageState.Failed
        }
        when (val current = state.value) {
            ImageState.Loading -> SkeletonBlock(Modifier.fillMaxSize())
            is ImageState.Loaded -> Image(
                bitmap = current.bitmap,
                contentDescription = name,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
            ImageState.Failed -> Box(
                modifier = Modifier
                    .fillMaxSize()
                    .testTag(TestTags.DETAIL_IMAGE_FAILED)
                    .background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    painter = painterResource(R.drawable.ic_image),
                    contentDescription = stringResource(R.string.product_img_failed),
                )
            }
        }
    }
}
