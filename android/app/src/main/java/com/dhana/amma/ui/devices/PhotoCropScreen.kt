package com.dhana.amma.ui.devices

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import kotlin.math.min
import kotlin.math.roundToInt

/** iOS has a built-in "Move and Scale" crop step (UIImagePickerController /
 * PhotosPicker); Compose has nothing equivalent, so this is a small
 * self-contained one: pinch to zoom, drag to pan, inside a fixed circular
 * viewport. On Confirm, the visible region is cropped out of the source
 * bitmap into a new square bitmap -- the app's own Circle clip (same as
 * every photo display elsewhere) handles rendering it round, so this
 * doesn't need to bake a circular alpha mask into the file. */
@Composable
fun PhotoCropScreen(image: Bitmap, onConfirm: (Bitmap) -> Unit, onCancel: () -> Unit) {
    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    var viewportSizePx by remember { mutableFloatStateOf(0f) }
    val density = LocalDensity.current
    val viewportDp = 280.dp

    // Scale that makes the shorter side of the image exactly fill the
    // (square) viewport at scale = 1 -- i.e. the same starting point as
    // ContentScale.Crop, before the user's own pinch/pan is applied.
    val baseScale = if (viewportSizePx > 0) {
        viewportSizePx / min(image.width, image.height).toFloat()
    } else 0f

    fun clampOffset(newScale: Float, newOffset: Offset): Offset {
        val displayedWidth = image.width * baseScale * newScale
        val displayedHeight = image.height * baseScale * newScale
        val maxX = ((displayedWidth - viewportSizePx) / 2f).coerceAtLeast(0f)
        val maxY = ((displayedHeight - viewportSizePx) / 2f).coerceAtLeast(0f)
        return Offset(newOffset.x.coerceIn(-maxX, maxX), newOffset.y.coerceIn(-maxY, maxY))
    }

    Column(
        modifier = Modifier.fillMaxSize().background(Color.Black),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(24.dp))
        Text(
            "Move and Scale",
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Pinch to zoom, drag to reposition",
            color = Color.White.copy(alpha = 0.7f),
            style = MaterialTheme.typography.bodySmall,
        )

        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .size(viewportDp)
                    .onSizeChanged { viewportSizePx = it.width.toFloat() }
                    .clip(CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                if (baseScale > 0f) {
                    Image(
                        bitmap = image.asImageBitmap(),
                        contentDescription = null,
                        modifier = Modifier
                            .size(
                                with(density) { (image.width * baseScale).toDp() },
                                with(density) { (image.height * baseScale).toDp() },
                            )
                            .graphicsLayer(
                                scaleX = scale,
                                scaleY = scale,
                                translationX = offset.x,
                                translationY = offset.y,
                            )
                            .pointerInput(baseScale) {
                                detectTransformGestures { _, pan, zoom, _ ->
                                    val newScale = (scale * zoom).coerceIn(1f, 5f)
                                    // Pan is in screen px at the CURRENT scale;
                                    // translationX/Y is applied on top of the
                                    // graphicsLayer's own scale, so the drag
                                    // distance needs the same scale factor
                                    // undone to track 1:1 with the finger.
                                    val newOffset = offset + pan * scale
                                    scale = newScale
                                    offset = clampOffset(newScale, newOffset)
                                }
                            },
                    )
                }
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(24.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            TextButton(onClick = onCancel) {
                Text("Cancel", color = Color.White)
            }
            Button(onClick = {
                onConfirm(cropBitmap(image, baseScale * scale, offset, viewportSizePx))
            }) {
                Text("Done")
            }
        }
    }
}

private fun cropBitmap(source: Bitmap, totalScale: Float, offset: Offset, viewportSizePx: Float): Bitmap {
    if (totalScale <= 0f || viewportSizePx <= 0f) return source
    val displayedTopLeftX = viewportSizePx / 2f - (source.width * totalScale) / 2f + offset.x
    val displayedTopLeftY = viewportSizePx / 2f - (source.height * totalScale) / 2f + offset.y

    val cropLeft = (-displayedTopLeftX / totalScale).coerceIn(0f, source.width.toFloat() - 1f)
    val cropTop = (-displayedTopLeftY / totalScale).coerceIn(0f, source.height.toFloat() - 1f)
    val cropSize = viewportSizePx / totalScale
    val width = cropSize.coerceAtMost(source.width - cropLeft).roundToInt().coerceAtLeast(1)
    val height = cropSize.coerceAtMost(source.height - cropTop).roundToInt().coerceAtLeast(1)

    return Bitmap.createBitmap(source, cropLeft.roundToInt(), cropTop.roundToInt(), width, height)
}
