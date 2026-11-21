package com.handstrudel.ui.studio.home

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.engine.CameraIssue
import com.handstrudel.engine.PlayInput
import com.handstrudel.ui.theme.LocalStudioPalette

/**
 * iOS `StudioInputPicker`: segmented "Air + touch" / "Touch only", a caption,
 * and "Open Camera Settings" after a denial. [onChange] persists the choice
 * (`studioPlayInput`) and switches the engine's input.
 */
@Composable
fun StudioInputPicker(selection: PlayInput, onChange: (PlayInput) -> Unit, modifier: Modifier = Modifier) {
    val palette = LocalStudioPalette.current
    val engine = LocalAppServices.current.engine
    val issue by engine.cameraIssue.collectAsState()
    val context = LocalContext.current
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(7.dp)) {
        val shape = RoundedCornerShape(9.dp)
        Row(
            Modifier.fillMaxWidth().testTag("studio-play-input").clip(shape)
                .background(palette.ink.copy(alpha = 0.08f)).padding(2.dp),
        ) {
            PlayInput.entries.forEach { input ->
                val selected = input == selection
                Box(
                    Modifier.weight(1f).heightIn(min = 36.dp).clip(RoundedCornerShape(7.dp))
                        .background(if (selected) palette.surface else palette.surface.copy(alpha = 0f))
                        .then(if (selected) Modifier.border(1.dp, palette.border, RoundedCornerShape(7.dp)) else Modifier)
                        .clickable { if (!selected) onChange(input) }
                        .testTag("studio-play-input-${input.raw}"),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        input.label, fontSize = 13.sp,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                        color = palette.ink,
                    )
                }
            }
        }
        Text(
            if (selection == PlayInput.AIR) "Use gestures or tap. Gestures use the front camera."
            else "Play the wheel by touch. The camera stays off.",
            fontSize = 12.sp, color = palette.muted,
        )
        if (issue == CameraIssue.PERMISSION_DENIED) {
            Text(
                "Open Camera Settings",
                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = palette.accent,
                modifier = Modifier.clickable {
                    context.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }.padding(vertical = 4.dp),
            )
        }
    }
}
