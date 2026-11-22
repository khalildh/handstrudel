package com.handstrudel.ui.social.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.AuthManager
import com.handstrudel.ui.social.SocialScreen
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.theme.LocalStudioPalette

/**
 * iOS `SignInView`: sign in (emailed code, or Google when configured), then pick a
 * username and accept the terms. Dismisses itself once the account is ready to post.
 */
@Composable
fun SignInSheet(onDismiss: () -> Unit, reason: String = "Sign in to post your performances.") {
    val social = rememberSocial() ?: return
    val auth = social.auth
    val userId by auth.userId.collectAsState()
    val needsSetup by auth.needsProfileSetupFlow.collectAsState()
    val error by auth.errorMessage.collectAsState()
    val signedIn = userId != null

    // Track the transition, not the initial state: an already-complete account still sees the sheet close.
    LaunchedEffect(signedIn, needsSetup) {
        if (signedIn && !needsSetup && auth.profile.value != null) onDismiss()
    }

    SocialScreen(
        title = if (signedIn) "Your profile" else "Sign in",
        onDismiss = onDismiss,
        dismissLabel = "Close",
        dismissOnLeading = true,
    ) {
        val p = LocalStudioPalette.current
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            if (signedIn) {
                ProfileSetupForm(auth)
            } else {
                Text(reason, color = p.muted, fontSize = 15.sp)
                GoogleSignInButton(auth)
                EmailCodeFlow(auth, showsOrHeader = GoogleSignIn.isAvailable)
            }
        }
    }

    error?.let { message ->
        AlertDialog(
            onDismissRequest = { auth.errorMessage.value = null },
            confirmButton = { TextButton(onClick = { auth.errorMessage.value = null }) { Text("OK") } },
            title = { Text("Something went wrong") },
            text = { Text(message) },
        )
    }
}

/** Convenience used where iOS checks `auth.isSignedIn && !auth.needsProfileSetup`. */
fun AuthManager.canAct(): Boolean = isSignedIn && !needsProfileSetup
