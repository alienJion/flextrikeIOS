package com.flextarget.android.ui.drills

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FastForward
import androidx.compose.material.icons.filled.FastRewind
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Playback controls for drill replay (Play, Pause, Next, Previous)
 */
@Composable
fun PlaybackControlsView(
    isPlaying: Boolean,
    onPlayPauseClick: () -> Unit,
    onNextClick: () -> Unit,
    onPrevClick: () -> Unit,
    canGoNext: Boolean = true,
    canGoPrev: Boolean = true,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 16.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Previous button
        IconButton(
            onClick = onPrevClick,
            enabled = canGoPrev,
            modifier = Modifier.size(48.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.FastRewind,
                contentDescription = "Previous",
                tint = if (canGoPrev) Color.White else Color.Gray,
                modifier = Modifier.size(32.dp)
            )
        }

        Spacer(modifier = Modifier.width(24.dp))

        // Play/Pause button
        Button(
            onClick = onPlayPauseClick,
            modifier = Modifier
                .size(64.dp),
            shape = androidx.compose.foundation.shape.CircleShape,
            colors = ButtonDefaults.buttonColors(
                containerColor = if (isPlaying) Color.Red else Color.Green
            ),
            contentPadding = PaddingValues(0.dp)
        ) {
            Text(
                text = if (isPlaying) "⏸" else "▶",
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall
            )
        }

        Spacer(modifier = Modifier.width(24.dp))

        // Next button
        IconButton(
            onClick = onNextClick,
            enabled = canGoNext,
            modifier = Modifier.size(48.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.FastForward,
                contentDescription = "Next",
                tint = if (canGoNext) Color.White else Color.Gray,
                modifier = Modifier.size(32.dp)
            )
        }
    }
}
