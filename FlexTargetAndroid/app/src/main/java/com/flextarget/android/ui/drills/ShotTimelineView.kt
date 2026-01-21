package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.model.ShotData
import kotlin.math.max
import kotlin.math.min

/**
 * Interactive timeline showing shot markers and allowing scrubbing
 */
@Composable
fun ShotTimelineView(
    shots: List<ShotData>,
    currentProgress: Double,
    totalDuration: Double,
    onProgressChanged: (Double) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth()
    ) {
        // Time display
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = formatTime(currentProgress),
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.width(50.dp)
            )

            Text(
                text = formatTime(totalDuration),
                color = Color.Gray,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.width(50.dp),
                textAlign = TextAlign.End
            )
        }

        // Timeline bar with simple markers
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(60.dp)
                .padding(horizontal = 16.dp)
                .background(
                    color = Color.DarkGray,
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(4.dp)
                )
                .pointerInput(totalDuration) {
                    detectTapGestures { offset ->
                        if (size.width > 0) {
                            val newProgress = (offset.x / size.width) * totalDuration
                            onProgressChanged(max(0.0, min(newProgress, totalDuration)))
                        }
                    }
                }
                .pointerInput(totalDuration) {
                    detectDragGestures { change, _ ->
                        if (size.width > 0) {
                            val newProgress = (change.position.x / size.width) * totalDuration
                            onProgressChanged(max(0.0, min(newProgress, totalDuration)))
                        }
                    }
                }
        ) {
            // Progress background
            if (totalDuration > 0) {
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .fillMaxWidth(fraction = (currentProgress / totalDuration).toFloat().coerceIn(0f, 1f))
                        .background(
                            color = Color.Green.copy(alpha = 0.6f),
                            shape = androidx.compose.foundation.shape.RoundedCornerShape(4.dp)
                        )
                )
            }

            // Current position indicator
            if (totalDuration > 0) {
                val positionFraction = (currentProgress / totalDuration).toFloat().coerceIn(0f, 1f)
                Box(
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .offset(x = (positionFraction * 100).dp - 6.dp)
                        .size(12.dp)
                        .background(Color.Red, shape = CircleShape)
                )
            }
        }

        // Shot markers display
        if (shots.isNotEmpty() && totalDuration > 0) {
            ShotMarkerRow(
                shots = shots,
                totalDuration = totalDuration,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            )
        }
    }
}

/**
 * Row displaying shot markers along the timeline
 */
@Composable
private fun ShotMarkerRow(
    shots: List<ShotData>,
    totalDuration: Double,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier.height(20.dp)) {
        var cumulativeTime = 0.0
        shots.forEach { shot ->
            cumulativeTime += shot.content.actualTimeDiff
            if (totalDuration > 0) {
                val positionFraction = cumulativeTime / totalDuration
                // Use a simple vertical line for markers
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .offset(x = (positionFraction * 100).dp)
                        .width(2.dp)
                        .fillMaxHeight()
                        .background(Color.White.copy(alpha = 0.7f))
                )
            }
        }
    }
}

/**
 * Format seconds to MM:SS format
 */
private fun formatTime(seconds: Double): String {
    val minutes = (seconds / 60).toInt()
    val secs = (seconds % 60).toInt()
    return String.format("%02d:%02d", minutes, secs)
}
