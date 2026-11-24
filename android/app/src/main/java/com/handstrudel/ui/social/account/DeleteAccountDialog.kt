package com.handstrudel.ui.social.account

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import com.handstrudel.ui.social.SocialMaterialTheme
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS "Delete your account?" alert with the destructive "Delete forever". */
@Composable
fun DeleteAccountDialog(onDismiss: () -> Unit, onConfirm: () -> Unit) {
    val p = LocalStudioPalette.current
    SocialMaterialTheme {
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text("Delete your account?") },
            text = { Text("This permanently removes your profile, videos, and comments. It can't be undone.") },
            confirmButton = { TextButton(onClick = onConfirm, modifier = Modifier.testTag("delete-forever")) { Text("Delete forever", color = p.recording) } },
            dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        )
    }
}

/** iOS "Couldn't confirm account deletion": the request's outcome is unknown, so the session stays. */
@Composable
fun AccountDeletionUnconfirmedDialog(onDismiss: () -> Unit) {
    SocialMaterialTheme {
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text("Couldn't confirm account deletion") },
            text = { Text("Check your connection and try again. If the problem continues, choose Get help in Account settings.") },
            confirmButton = { TextButton(onClick = onDismiss) { Text("OK") } },
        )
    }
}
