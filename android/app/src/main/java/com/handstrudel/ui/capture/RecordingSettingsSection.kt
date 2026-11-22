package com.handstrudel.ui.capture

import androidx.compose.material.icons.outlined.DoNotTouch
import com.handstrudel.ui.theme.StudioFonts
import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.outlined.PanTool
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.capture.AppAudioCapture
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS `ControlSheetView.recordingSection`. */
@Composable
internal fun RecordingSettingsSectionView() {
    val prefs = LocalAppServices.current.prefs
    val palette = LocalStudioPalette.current
    val context = LocalContext.current
    val hideSkeleton by prefs.hideSkeletonWhenRecording.collectAsState()
    val microphone by prefs.recordPerformanceMicrophone.collectAsState()
    val micPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        prefs.setRecordPerformanceMicrophone(granted)
    }
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Filled.Videocam, null, tint = palette.accent, modifier = Modifier.size(14.dp))
            Text("RECORDING", fontFamily = StudioFonts.Mono, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, color = palette.accent)
        }
        ToggleRow(Icons.Outlined.DoNotTouch, "Hide hand tracking in recordings", hideSkeleton, "hide-skeleton-recording") {
            prefs.setHideSkeletonWhenRecording(it)
        }
        HorizontalDivider(color = palette.border)
        ToggleRow(Icons.Filled.Mic, "Include microphone (solo takes)", microphone, "record-microphone") { on ->
            if (on && !AppAudioCapture.hasRecordPermission(context)) micPermission.launch(Manifest.permission.RECORD_AUDIO)
            else prefs.setRecordPerformanceMicrophone(on)
        }
    }
}

@Composable
private fun ToggleRow(icon: ImageVector, label: String, checked: Boolean, tag: String, onChange: (Boolean) -> Unit) {
    val palette = LocalStudioPalette.current
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = palette.ink, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(10.dp))
        Text(label, color = palette.ink, fontSize = 15.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        Switch(
            checked = checked, onCheckedChange = onChange, modifier = Modifier.testTag(tag),
            colors = SwitchDefaults.colors(checkedTrackColor = palette.accent, checkedThumbColor = palette.onAccent),
        )
    }
}
