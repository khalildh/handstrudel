package com.handstrudel.ui.studio.pickers

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.models.CustomScale
import com.handstrudel.models.MusicKey
import com.handstrudel.ui.studio.common.StudioMusic
import com.handstrudel.ui.studio.common.StudioSheet
import com.handstrudel.ui.theme.LocalStudioPalette
import java.util.UUID

/** iOS `PersistenceManager.customScaleLimit`. */
const val CUSTOM_SCALE_LIMIT = 64

/**
 * Editor state for iOS `CustomScaleEditor`: the root (interval 0) is fixed,
 * [scale] is non-null only when the name and notes make a valid scale.
 */
class CustomScaleDraft(val id: UUID, name: String, notes: Set<Int>) {
    var name: String = name
    var notes: Set<Int> = notes + 0
        private set

    fun toggle(interval: Int) {
        if (interval == 0) return
        notes = if (interval in notes) notes - interval else notes + interval
    }

    val scale: CustomScale? get() = CustomScale.create(id, name, notes.sorted())

    companion object {
        fun from(existing: CustomScale?, seed: List<Int>) =
            CustomScaleDraft(existing?.id ?: UUID.randomUUID(), existing?.name ?: "", (existing?.intervals ?: seed).toSet())
    }
}

/** iOS `CustomScaleEditor`: name, 12-note grid (root locked), "Save & Use". */
@Composable
fun CustomScaleEditor(
    key: MusicKey,
    existing: CustomScale?,
    seed: List<Int>,
    onSave: (CustomScale) -> Boolean,
    onDismiss: () -> Unit,
) {
    val palette = LocalStudioPalette.current
    val draft = remember(existing) { CustomScaleDraft.from(existing, seed) }
    var name by remember { mutableStateOf(draft.name) }
    var notes by remember { mutableStateOf(draft.notes) }
    var saveFailed by remember { mutableStateOf(false) }
    val valid = CustomScale.create(draft.id, name, notes.sorted())

    StudioSheet(
        title = "Custom Scale",
        onDismiss = onDismiss,
        leadingAction = "Cancel" to onDismiss,
        trailingAction = "Save & Use" to {
            valid?.let { if (onSave(it)) onDismiss() else saveFailed = true }
        },
        trailingEnabled = valid != null,
        trailingTag = "custom-scale-save",
    ) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("Name", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = palette.muted)
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                placeholder = { Text("My scale") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().testTag("custom-scale-name"),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = palette.ink, unfocusedTextColor = palette.ink,
                    focusedBorderColor = palette.accent, unfocusedBorderColor = palette.border, cursorColor = palette.accent,
                ),
            )
            Text("Notes in ${key.displayName}", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = palette.muted,
                modifier = Modifier.padding(top = 8.dp))
            for (row in 0 until 4) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    for (col in 0 until 3) {
                        val interval = row * 3 + col
                        val included = interval in notes
                        val note = StudioMusic.pitchClassName(60 + key.semitone + interval)
                        Row(
                            Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
                                .background(if (included) palette.accent else palette.surface)
                                .clickable(enabled = interval != 0) {
                                    notes = if (included) notes - interval else notes + interval
                                }
                                .testTag("custom-scale-note-$interval"),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                when { interval == 0 -> Icons.Filled.Lock; included -> Icons.Filled.CheckCircle; else -> Icons.Outlined.Circle },
                                null, tint = if (included) palette.onAccent else palette.ink, modifier = Modifier.size(16.dp),
                            )
                            Text(
                                " $note", fontSize = 15.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold,
                                color = if (included) palette.onAccent else palette.ink,
                            )
                        }
                    }
                }
            }
            Text(
                "Keep the root and select at least two more notes. Your pattern follows you when you change key.",
                fontSize = 12.sp, color = palette.muted,
            )
            if (saveFailed) {
                Text(
                    "Couldn't save the scale. You can keep up to $CUSTOM_SCALE_LIMIT custom scales.",
                    fontSize = 14.sp, color = palette.muted,
                )
            }
        }
    }
}
