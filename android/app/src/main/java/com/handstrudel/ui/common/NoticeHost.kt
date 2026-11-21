package com.handstrudel.ui.common

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.ui.nav.DefaultAppNavigator
import com.handstrudel.ui.theme.LocalStudioPalette

/**
 * Global notice toast (iOS `draftPostNotice` overlay): top-centred, non-interactive,
 * shown for `millis` by [DefaultAppNavigator.showNotice]. Test tag `draft-post-notice`
 * (the iOS identifier) so one test plan describes both apps.
 */
@Composable
fun NoticeHost(notice: DefaultAppNavigator.Notice?, modifier: Modifier = Modifier) {
    val palette = LocalStudioPalette.current
    Box(
        modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal))
            .padding(horizontal = 16.dp)
            .padding(top = 54.dp),
        contentAlignment = Alignment.TopCenter,
    ) {
        AnimatedContent(
            targetState = notice,
            transitionSpec = { (fadeIn() + slideInVertically { -it / 3 }) togetherWith fadeOut() },
            contentKey = { it?.id },
            label = "notice",
        ) { current ->
            if (current != null) {
                val shape = RoundedCornerShape(12.dp)
                Text(
                    current.text,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    color = palette.ink,
                    modifier = Modifier
                        .widthIn(max = 520.dp)
                        .clip(shape)
                        .background(palette.surface.copy(alpha = 0.94f))
                        .border(1.dp, palette.border, shape)
                        .padding(12.dp)
                        .semantics { liveRegion = LiveRegionMode.Polite }
                        .testTag("draft-post-notice"),
                )
            }
        }
    }
}

/** Global alert (iOS `.alert("HandStrudel", …) { Button("OK") }`). */
@Composable
fun ErrorAlertHost(error: DefaultAppNavigator.ErrorAlert?, onDismiss: () -> Unit) {
    val e = error ?: return
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss, modifier = Modifier.testTag("alert-ok")) { Text("OK") } },
        title = { Text(e.title) },
        text = { Text(e.message, modifier = Modifier.testTag("alert-message")) },
    )
}
