package com.handstrudel.ui.capture

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
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
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
import com.handstrudel.ui.theme.IosSwitch
import com.handstrudel.ui.theme.StudioIcons
import com.handstrudel.ui.studio.common.SectionHeader

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
        SectionHeader("RECORDING", StudioIcons.Video)
        ToggleRow(StudioIcons.HandRaisedSlash, "Hide hand tracking in recordings", hideSkeleton, "hide-skeleton-recording") {
            prefs.setHideSkeletonWhenRecording(it)
        }
        // iOS `sectionDivider`: ink at 6 %, 1 pt.
        HorizontalDivider(thickness = 1.dp, color = palette.ink.copy(alpha = 0.06f))
        ToggleRow(StudioIcons.Mic, "Include microphone (solo takes)", microphone, "record-microphone") { on ->
            if (on && !AppAudioCapture.hasRecordPermission(context)) micPermission.launch(Manifest.permission.RECORD_AUDIO)
            else prefs.setRecordPerformanceMicrophone(on)
        }
    }
}

@Composable
private fun ToggleRow(icon: ImageVector, label: String, checked: Boolean, tag: String, onChange: (Boolean) -> Unit) {
    val palette = LocalStudioPalette.current
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = palette.ink, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(8.dp))
        Text(label, color = palette.ink, fontSize = 15.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        IosSwitch(checked = checked, onCheckedChange = onChange, modifier = Modifier.testTag(tag))
    }
}
