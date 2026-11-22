package com.handstrudel.ui.social.auth

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.handstrudel.social.AuthManager
import com.handstrudel.social.SocialConfig
import com.handstrudel.ui.social.ProfileActionButton
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.launch
import java.security.MessageDigest
import java.security.SecureRandom

/** iOS `SignInView.emailSection`: email → "Email me a code" → 6-digit code → "Sign in". */
@Composable
fun EmailCodeFlow(auth: AuthManager, showsOrHeader: Boolean) {
    if (!SocialConfig.EMAIL_SIGN_IN_ENABLED) return
    val p = LocalStudioPalette.current
    val scope = rememberCoroutineScope()
    var email by rememberSaveable { mutableStateOf("") }
    var code by rememberSaveable { mutableStateOf("") }
    var codeSent by rememberSaveable { mutableStateOf(false) }
    var busy by rememberSaveable { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(if (showsOrHeader) "OR USE YOUR EMAIL" else "USE YOUR EMAIL", color = p.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        OutlinedTextField(
            value = email, onValueChange = { email = it },
            placeholder = { Text("you@example.com") }, singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, capitalization = KeyboardCapitalization.None,
                autoCorrectEnabled = false, imeAction = ImeAction.Done),
            modifier = Modifier.fillMaxWidth().testTag("sign-in-email"),
        )
        if (codeSent) {
            OutlinedTextField(
                value = code, onValueChange = { code = it.filter(Char::isDigit).take(10) },
                placeholder = { Text("6-digit code") }, singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Done),
                modifier = Modifier.fillMaxWidth().testTag("sign-in-code"),
            )
            ProfileActionButton(
                "Sign in", primary = true, enabled = code.length >= 6 && !busy,
                modifier = Modifier.fillMaxWidth().testTag("verify-sign-in-code"),
                onClick = { scope.launch { busy = true; auth.verifyEmailCode(code, email); busy = false } },
            )
        } else {
            ProfileActionButton(
                "Email me a code", primary = true, enabled = email.contains("@") && !busy,
                modifier = Modifier.fillMaxWidth(),
                onClick = { scope.launch { busy = true; codeSent = auth.sendEmailCode(email); busy = false } },
            )
        }
    }
}

/** Google via Credential Manager; only built when `GOOGLE_WEB_CLIENT_ID` is set (Risk R4). */
object GoogleSignIn {
    val isAvailable: Boolean get() = SocialConfig.googleWebClientId.isNotBlank()

    fun nonce(): Pair<String, String> {
        val bytes = ByteArray(24).also { SecureRandom().nextBytes(it) }
        val raw = bytes.joinToString("") { "%02x".format(it) }
        val hashed = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray()).joinToString("") { "%02x".format(it) }
        return raw to hashed
    }
}

@Composable
fun GoogleSignInButton(auth: AuthManager) {
    if (!GoogleSignIn.isAvailable) return
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by rememberSaveable { mutableStateOf(false) }
    ProfileActionButton("Continue with Google", enabled = !busy, modifier = Modifier.fillMaxWidth(), onClick = {
        val activity = context.findActivity() ?: return@ProfileActionButton
        scope.launch {
            busy = true
            try {
                val (raw, hashed) = GoogleSignIn.nonce()
                val option = GetGoogleIdOption.Builder()
                    .setServerClientId(SocialConfig.googleWebClientId)
                    .setFilterByAuthorizedAccounts(false)
                    .setNonce(hashed)
                    .build()
                val result = CredentialManager.create(activity)
                    .getCredential(activity, GetCredentialRequest.Builder().addCredentialOption(option).build())
                val credential = result.credential
                if (credential is CustomCredential && credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                    auth.signInWithGoogle(GoogleIdTokenCredential.createFrom(credential.data).idToken, raw)
                } else {
                    auth.errorMessage.value = "Google didn't return a sign-in token."
                }
            } catch (e: GetCredentialCancellationException) {
                // user backed out
            } catch (e: Exception) {
                auth.errorMessage.value = "Google sign-in didn't go through. Please try again."
            } finally {
                busy = false
            }
        }
    })
}

private fun Context.findActivity(): Activity? {
    var c: Context? = this
    while (c is ContextWrapper) { if (c is Activity) return c; c = c.baseContext }
    return null
}
