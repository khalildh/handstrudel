package com.handstrudel.ui.studio.overlays

import com.handstrudel.ui.theme.StudioIcons

import androidx.compose.foundation.layout.statusBarsPadding
import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.automirrored.outlined.NoteAdd
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Display metadata for one picker entry (iOS `LearnSong` name/emoji/bpm). */
internal data class LearnSongEntry(val id: String, val name: String, val emoji: String, val bpm: Int)

/** The picker's catalog: the engine's `BUNDLED_SONGS` (iOS `Models/LearnSong.swift`), in order. */
internal val LEARN_PICKER_SONGS: List<LearnSongEntry> =
    com.handstrudel.models.BUNDLED_SONGS.map { LearnSongEntry(it.id, it.name, it.emoji, it.bpm.toInt()) }

/** iOS practice generators: (label, icon, generated song name → id). */
internal data class PracticeEntry(val label: String, val songName: String) {
    val id: String get() = learnSongId(songName)
}

/**
 * iOS `LearnSong.ascending(noteCount: 10)`, `.descending(10)`, `.arpeggio(14)`,
 * `.random(12)`; the generated song is named e.g. "Ascending 10". Ids match the
 * engine's `PRACTICE_SONG_IDS` (random regenerates per load).
 */
internal val LEARN_PRACTICE: List<PracticeEntry> = listOf(
    PracticeEntry("Ascending", "Ascending 10"),
    PracticeEntry("Descending", "Descending 10"),
    PracticeEntry("Arpeggio", "Arpeggio 14"),
    PracticeEntry("Random", "Random 12"),
)

/** Song id = snake_case of the name: lowercase, runs of non-alphanumerics → `_`. */
internal fun learnSongId(name: String): String =
    name.lowercase().replace(Regex("[^a-z0-9]+"), "_").trim('_')

private fun practiceIcon(label: String): ImageVector = when (label) {
    "Ascending" -> Icons.Filled.ArrowUpward
    "Descending" -> Icons.Filled.ArrowDownward
    "Arpeggio" -> StudioIcons.Waveform
    else -> Icons.Filled.Casino
}

private val PickerGreen = Color(0xFF30D158)

/** iOS `LearnSongPicker`: black sheet with MELODIES (2-column cards), PRACTICE and IMPORT. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LearnSongPicker(onPick: (songId: String) -> Unit, onDismiss: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    fun select(id: String) {
        onPick(id)
        onDismiss()
    }
    ModalBottomSheet(
        modifier = Modifier.statusBarsPadding(),
        onDismissRequest = onDismiss,
        sheetState = state,
        containerColor = Color.Black,
        contentColor = Color.White,
        dragHandle = null,
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Text(
                "LEARN", fontSize = 32.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, color = Color.White,
                modifier = Modifier.padding(top = 20.dp),
            )

            SectionHeader("MELODIES")
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                LEARN_PICKER_SONGS.chunked(2).forEach { pair ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        pair.forEach { song ->
                            SongCard(song, Modifier.weight(1f).clickable { select(song.id) }.testTag("song-${song.name}"))
                        }
                        if (pair.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }

            SectionHeader("PRACTICE")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LEARN_PRACTICE.forEach { practice -> PracticeButton(practice) { select(practice.id) } }
            }

            SectionHeader("IMPORT")
            val importShape = RoundedCornerShape(14.dp)
            Row(
                Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .background(Color.White.copy(alpha = 0.04f), importShape)
                    .border(1.dp, Color.White.copy(alpha = 0.08f), importShape)
                    // Placeholder: MIDI import is not implemented on iOS 1.0.1 either.
                    .clickable { },
                horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.AutoMirrored.Outlined.NoteAdd, contentDescription = null, tint = Color.White.copy(alpha = 0.5f), modifier = Modifier.size(18.dp))
                Text("Import MIDI", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Rounded, color = Color.White.copy(alpha = 0.5f))
            }

            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.width(24.dp).height(1.dp).background(Color.White.copy(alpha = 0.15f)))
        Text(title, fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = Color.White.copy(alpha = 0.35f), letterSpacing = 2.sp)
        Box(Modifier.width(24.dp).height(1.dp).background(Color.White.copy(alpha = 0.15f)))
    }
}

@Composable
private fun SongCard(song: LearnSongEntry, modifier: Modifier) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier
            .background(Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.06f), Color.White.copy(alpha = 0.02f))), shape)
            .border(1.dp, Color.White.copy(alpha = 0.08f), shape)
            .padding(vertical = 16.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(song.emoji, fontSize = 30.sp)
        Text(
            song.name, fontSize = 13.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = Color.White,
            maxLines = 1, overflow = TextOverflow.Ellipsis,
        )
        Text(
            "${song.bpm} BPM", fontSize = 10.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Mono,
            color = PickerGreen.copy(alpha = 0.7f),
        )
    }
}

@Composable
private fun PracticeButton(practice: PracticeEntry, onClick: () -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Column(
        Modifier
            .size(width = 90.dp, height = 72.dp)
            .background(Brush.verticalGradient(listOf(PickerGreen.copy(alpha = 0.15f), PickerGreen.copy(alpha = 0.05f))), shape)
            .border(1.dp, PickerGreen.copy(alpha = 0.3f), shape)
            .clickable(onClick = onClick)
            .testTag("practice-${practice.label.lowercase()}"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
    ) {
        Icon(practiceIcon(practice.label), contentDescription = null, tint = PickerGreen, modifier = Modifier.size(22.dp))
        Text(practice.label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Rounded, color = Color.White.copy(alpha = 0.8f))
    }
}
