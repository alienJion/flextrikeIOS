package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.Image
import com.flextarget.android.data.model.ShotData

/**
 * Preview display showing the target image with bullet hole overlays
 */
@Composable
fun TargetPreviewView(
    shots: List<ShotData>,
    currentShotIndex: Int,
    modifier: Modifier = Modifier
) {
    if (shots.isEmpty()) {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .height(400.dp)
                .background(Color.Black)
                .border(1.dp, Color.Gray),
            contentAlignment = Alignment.Center
        ) {
            Text("No shots to display", color = Color.Gray)
        }
        return
    }

    // Get the current shot and active target type
    val currentShot = shots.getOrNull(currentShotIndex)
    val activeTargetType = currentShot?.content?.actualTargetType ?: "ipsc"

    // Get all shots up to current that match the current target type
    val relevantShots = shots
        .take(currentShotIndex + 1)
        .filter { it.content.actualTargetType == activeTargetType }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(400.dp)
            .background(Color.Black)
            .border(1.dp, Color.DarkGray)
    ) {
        // Target image background
        val assetName = TargetAssetMapper.getTargetImageAssetName(activeTargetType)
        val resId = getDrawableResourceId(assetName)

        if (resId != 0) {
            Image(
                painter = painterResource(id = resId),
                contentDescription = "Target",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit,
                alignment = Alignment.Center
            )
        } else {
            // Fallback: show placeholder
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.DarkGray),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "Target: $activeTargetType",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        }

        // Overlay bullet holes for relevant shots
        Box(
            modifier = Modifier.fillMaxSize()
        ) {
            relevantShots.forEach { shot ->
                val hitPos = shot.content.actualHitPosition
                val x = hitPos.x.toFloat()
                val y = hitPos.y.toFloat()

                // Bullet hole marker (small circle)
                Box(
                    modifier = Modifier
                        .offset(
                            x = (x * 100).dp - 8.dp,
                            y = (y * 100).dp - 8.dp
                        )
                        .size(width = 16.dp, height = 16.dp)
                        .background(
                            color = Color.Red.copy(alpha = 0.7f),
                            shape = CircleShape
                        )
                        .border(2.dp, Color.White, CircleShape)
                )
            }
        }

        // Shot counter
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(16.dp)
                .background(Color.Black.copy(alpha = 0.7f), shape = RoundedCornerShape(4.dp))
                .padding(8.dp)
        ) {
            Text(
                text = "${currentShotIndex + 1}",
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall
            )
        }
    }
}

/**
 * Helper to get drawable resource ID from asset name
 */
private fun getDrawableResourceId(assetName: String): Int {
    return try {
        val resourceName = assetName.replace(".", "_")
        val clazz = Class.forName("com.flextarget.android.R\$drawable")
        val field = clazz.getField(resourceName)
        field.getInt(null)
    } catch (e: Exception) {
        0
    }
}
