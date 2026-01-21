package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.ShotData
import kotlin.math.min

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillReplayView(
    drillSetup: DrillSetupEntity,
    shots: List<ShotData> = emptyList(),
    onBack: () -> Unit = {}
) {
    // State management - local Composable state for simplicity
    var currentProgress by remember { mutableStateOf(0.0) }
    var isPlaying by remember { mutableStateOf(false) }

    // Calculate timing information
    val totalDuration = remember(shots) { TimingCalculator.calculateTotalDuration(shots) }
    val currentShotIndex = remember(currentProgress, shots) {
        TimingCalculator.findShotAtTime(shots, currentProgress)
    }

    // Timer for playback - 50ms updates for smooth animation
    LaunchedEffect(isPlaying) {
        if (isPlaying) {
            while (isPlaying && currentProgress < totalDuration) {
                kotlinx.coroutines.delay(50) // 50ms per frame
                currentProgress += 0.05
            }
            if (currentProgress >= totalDuration) {
                isPlaying = false
                currentProgress = totalDuration
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Drill Replay", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.Red
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        if (shots.isEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .padding(16.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "No shots to replay",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .padding(horizontal = 16.dp, vertical = 12.dp)
            ) {
                // Top: Target preview area
                TargetPreviewView(
                    shots = shots,
                    currentShotIndex = currentShotIndex,
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Bottom: Timeline and controls
                ShotTimelineView(
                    shots = shots,
                    currentProgress = currentProgress,
                    totalDuration = totalDuration,
                    onProgressChanged = { newProgress ->
                        currentProgress = newProgress
                        // Stop playback when user manually scrubs
                        isPlaying = false
                    }
                )

                // Playback controls
                PlaybackControlsView(
                    isPlaying = isPlaying,
                    onPlayPauseClick = { isPlaying = !isPlaying },
                    onNextClick = {
                        // Jump to next shot
                        if (currentShotIndex < shots.size - 1) {
                            currentProgress = TimingCalculator.getTimeAtShotIndex(shots, currentShotIndex + 1)
                        } else {
                            currentProgress = totalDuration
                        }
                        isPlaying = false
                    },
                    onPrevClick = {
                        // Jump to previous shot
                        if (currentShotIndex > 0) {
                            currentProgress = TimingCalculator.getTimeAtShotIndex(shots, currentShotIndex - 1)
                        } else {
                            currentProgress = 0.0
                        }
                        isPlaying = false
                    },
                    canGoNext = currentShotIndex < shots.size - 1,
                    canGoPrev = currentShotIndex > 0
                )

                // Shot details list
                Spacer(modifier = Modifier.height(8.dp))

                ShotDetailsPanel(
                    shots = shots,
                    currentShotIndex = currentShotIndex,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp)
                )
            }
        }
    }
}

/**
 * Panel showing details of shots in a horizontal scrollable list
 */
@Composable
private fun ShotDetailsPanel(
    shots: List<ShotData>,
    currentShotIndex: Int,
    modifier: Modifier = Modifier
) {
    if (shots.isEmpty()) return

    Column(modifier = modifier) {
        Text(
            text = "Shot ${currentShotIndex + 1} of ${shots.size}",
            color = Color.White,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            items(shots.take(currentShotIndex + 1).size) { index ->
                val shot = shots[index]
                val isCurrent = index == currentShotIndex

                ShotDetailItem(
                    shot = shot,
                    shotNumber = index + 1,
                    isCurrent = isCurrent
                )
            }
        }
    }
}

@Composable
private fun ShotDetailItem(
    shot: ShotData,
    shotNumber: Int,
    isCurrent: Boolean
) {
    val backgroundColor = when {
        isCurrent -> Color.Red.copy(alpha = 0.8f)
        else -> Color.DarkGray.copy(alpha = 0.6f)
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = backgroundColor)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "#$shotNumber",
                color = Color.White,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.width(40.dp)
            )

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "${shot.content.actualTargetType} - ${shot.content.actualHitArea}",
                    color = Color.White,
                    style = MaterialTheme.typography.bodySmall
                )
            }

            Text(
                text = String.format("%.2fs", shot.content.actualTimeDiff),
                color = if (shot.content.actualTimeDiff > 0) Color.Green else Color.Red,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.width(50.dp)
            )
        }
    }
}