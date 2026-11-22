package com.handstrudel.ui.social.feed

import com.handstrudel.ui.theme.StudioIcons

import androidx.compose.foundation.layout.statusBarsPadding
import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.model.Video
import com.handstrudel.ui.social.ProfileActionButton
import com.handstrudel.ui.social.SocialMaterialTheme
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS `FeedSoundSheet`: "Play this sound", "Play along", "Save preset privately". */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedSoundSheet(video: Video, onDismiss: () -> Unit, onStart: (PerformanceStart) -> Unit) {
    val p = LocalStudioPalette.current
    val title = video.soundSetup?.instrumentName ?: video.instrument ?: "Sound"
    SocialMaterialTheme {
        ModalBottomSheet(onDismissRequest = onDismiss, modifier = Modifier.statusBarsPadding(), sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = p.background) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 22.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Sound options", color = p.ink, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    TextButton(onClick = onDismiss) { Text("Done", color = p.accent, fontWeight = FontWeight.SemiBold) }
                }
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(StudioIcons.Waveform, null, tint = p.ink, modifier = Modifier.size(22.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(title, color = p.ink, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
                    }
                    video.soundSetup?.let { Text(it.presetDetails, color = p.muted, fontSize = 15.sp, fontFamily = StudioFonts.Mono) }
                }
                video.soundSetup?.let { setup ->
                    ProfileActionButton("Play this sound", primary = true, icon = Icons.Filled.PlayArrow,
                        modifier = Modifier.fillMaxWidth().testTag("play-clip-preset"), onClick = { onStart(PerformanceStart.Preset(setup)) })
                }
                if (video.backingEnabled == true) {
                    ProfileActionButton("Play along", primary = video.soundSetup == null, icon = StudioIcons.Waveform,
                        modifier = Modifier.fillMaxWidth().testTag("play-along"), onClick = { onStart(PerformanceStart.Backing(video)) })
                }
                video.soundSetup?.let { setup -> SavePresetButton(setup, savedName(title, video.username)) }
            }
        }
    }
}

/** iOS: "<instrument> by @<creator>", saved privately as a preset (≤ 40 chars). */
fun savedName(title: String, username: String?): String = username?.let { "$title by @$it" } ?: title

@Composable
fun SavePresetButton(setup: SoundSetup, name: String, compact: Boolean = false) {
    val engine = LocalAppServices.current.engine
    val presets by engine.presets.collectAsState()
    val saved = presets.any { it.sound == setup && it.name == name.take(40) }
    ProfileActionButton(
        if (compact) "" else if (saved) "Preset saved" else "Save preset privately",
        icon = if (saved) Icons.Filled.Check else Icons.Outlined.BookmarkBorder,
        enabled = !saved,
        contentDescription = if (saved) "Preset saved" else "Save preset privately",
        modifier = (if (compact) Modifier.size(44.dp) else Modifier.fillMaxWidth()).testTag("save-clip-preset"),
        onClick = { engine.addPreset(setup, name) },
    )
}
