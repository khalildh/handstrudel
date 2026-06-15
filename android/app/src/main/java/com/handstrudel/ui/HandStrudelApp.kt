package com.handstrudel.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.util.Log
import com.handstrudel.engine.EngineController
import com.handstrudel.engine.HandsState
import com.handstrudel.models.PRESETS
import com.handstrudel.models.Preset
import uniffi.handstrudel_core.MusicKey as CoreKey
import uniffi.handstrudel_core.Scale as CoreScale
import uniffi.handstrudel_core.chordDisplayName
import uniffi.handstrudel_core.chordNotes
import uniffi.handstrudel_core.midiNoteName

@Composable
fun HandStrudelApp() {
    val context = LocalContext.current
    var isRunning by remember { mutableStateOf(false) }
    val engine = remember { EngineController(context) }

    Box(modifier = Modifier.fillMaxSize()) {
        if (!isRunning) {
            StartScreen(
                onStart = { preset ->
                    engine.start(preset)
                    isRunning = true
                }
            )
        } else {
            PerformanceScreen(engine = engine)
        }
    }
}

@Composable
fun PerformanceScreen(engine: EngineController) {
    val handsState by engine.handsState.collectAsState()
    val beat by engine.currentBeat.collectAsState()

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        // Camera preview (full screen)
        CameraPreview(
            modifier = Modifier.fillMaxSize(),
            handTracker = engine.handTracker
        )

        // Split chord+melody overlay — the app's default playable surface.
        // Sits under the hand skeleton so finger tracking stays visible.
        if (engine.chordMelodyModeEnabled) {
            SplitChordMelodyOverlay(engine = engine, modifier = Modifier.fillMaxSize())
        }

        // Hand skeleton overlay
        HandOverlay(
            handsState = handsState,
            modifier = Modifier.fillMaxSize()
        )

        // Top bar — logo + mode indicator
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 50.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                "handstrudel",
                fontSize = 20.sp,
                fontWeight = FontWeight.Black,
                color = Color.White.copy(alpha = 0.8f)
            )

            // Beat dots
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.padding(top = 8.dp)
            ) {
                for (i in 0..3) {
                    Box(
                        modifier = Modifier
                            .size(if (i == beat) 10.dp else 6.dp)
                            .clip(CircleShape)
                            .background(
                                if (i == beat) Color(0xFF00FF9E)
                                else Color.White.copy(alpha = 0.2f)
                            )
                    )
                }
            }
        }

        // Bottom controls
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(bottom = 40.dp, start = 20.dp, end = 20.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Mode indicator
            val modeText = when {
                engine.gridModeEnabled -> "GRID"
                engine.drumModeEnabled -> "DRUMS"
                engine.chordMelodyModeEnabled -> "SPLIT"
                else -> "MELODIC"
            }
            Text(
                modeText,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF00FF9E),
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color(0xFF00FF9E).copy(alpha = 0.15f))
                    .padding(horizontal = 12.dp, vertical = 6.dp)
            )

            // BPM
            Text(
                "${engine.manualBPM.toInt()}",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF00FF9E)
            )

            // Preset name
            Text(
                engine.selectedPreset?.emoji ?: "",
                fontSize = 24.sp
            )
        }
    }
}

@Composable
fun StartScreen(onStart: (Preset) -> Unit) {
    var selectedPreset by remember { mutableStateOf<Preset?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 20.dp)
            .padding(top = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Logo
        Text(
            text = "handstrudel",
            fontSize = 36.sp,
            fontWeight = FontWeight.Black,
            color = Color.White,
            letterSpacing = (-1).sp
        )
        Text(
            text = "your hands are the instrument",
            fontSize = 14.sp,
            color = Color.White.copy(alpha = 0.5f),
            modifier = Modifier.padding(top = 4.dp, bottom = 8.dp)
        )


        // Section header
        Text(
            text = "PICK A VIBE",
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White.copy(alpha = 0.3f),
            letterSpacing = 3.sp,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        // Preset grid
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.weight(1f)
        ) {
            items(PRESETS) { preset ->
                PresetCard(
                    preset = preset,
                    isSelected = selectedPreset?.id == preset.id,
                    onTap = { selectedPreset = preset }
                )
            }
        }

        // Start button
        Button(
            onClick = { selectedPreset?.let { onStart(it) } },
            enabled = selectedPreset != null,
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 20.dp)
                .height(56.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFF00FF9E),
                contentColor = Color.Black,
                disabledContainerColor = Color.White.copy(alpha = 0.1f),
                disabledContentColor = Color.White.copy(alpha = 0.3f)
            )
        ) {
            Text(
                "LET'S GO",
                fontSize = 18.sp,
                fontWeight = FontWeight.Black
            )
        }
    }
}

@Composable
fun PresetCard(preset: Preset, isSelected: Boolean, onTap: () -> Unit) {
    val bgColor = if (isSelected) Color(0xFF00FF9E).copy(alpha = 0.08f) else Color.White.copy(alpha = 0.04f)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(bgColor)
            .clickable { onTap() }
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(preset.emoji, fontSize = 28.sp)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                preset.name,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = if (isSelected) Color(0xFF00FF9E) else Color.White
            )
            Text(
                preset.description,
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.5f),
                textAlign = TextAlign.Center
            )

            if (preset.isPremium) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    "PRO",
                    fontSize = 9.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = Color.White.copy(alpha = 0.7f),
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color.White.copy(alpha = 0.15f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                )
            }
        }
    }
}
