package com.handstrudel.ui.social.auth

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.draw.clip
import androidx.compose.ui.Alignment
import androidx.compose.material3.HorizontalDivider
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
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

    // iOS inset-grouped `Form` section: a caps header over one card of plain rows,
    // with the action as a tinted text row inside the same group.
    FormSection(if (showsOrHeader) "OR USE YOUR EMAIL" else "USE YOUR EMAIL") {
        FormFieldRow(
            email, { email = it }, "you@example.com",
            KeyboardOptions(keyboardType = KeyboardType.Email, capitalization = KeyboardCapitalization.None,
                autoCorrectEnabled = false, imeAction = ImeAction.Done),
            Modifier.testTag("sign-in-email"),
        )
        if (codeSent) {
            FormDivider()
            FormFieldRow(
                code, { code = it.filter(Char::isDigit).take(10) }, "6-digit code",
                KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Done),
                Modifier.testTag("sign-in-code"),
            )
            FormDivider()
            FormButtonRow("Sign in", enabled = code.length >= 6 && !busy, modifier = Modifier.testTag("verify-sign-in-code")) {
                scope.launch { busy = true; auth.verifyEmailCode(code, email); busy = false }
            }
        } else {
            FormDivider()
            FormButtonRow("Email me a code", enabled = email.contains("@") && !busy) {
                scope.launch { busy = true; codeSent = auth.sendEmailCode(email); busy = false }
            }
        }
    }
}

/** iOS inset-grouped `Section`: optional caps header (footnote, muted) over a rounded surface card. */
@Composable
internal fun FormSection(header: String?, content: @Composable ColumnScope.() -> Unit) {
    val p = LocalStudioPalette.current
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        if (header != null) Text(header, color = p.muted, fontSize = 13.sp, modifier = Modifier.padding(start = 16.dp))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(p.surface), content = content)
    }
}

@Composable
internal fun FormDivider() {
    HorizontalDivider(Modifier.padding(start = 16.dp), color = LocalStudioPalette.current.border)
}

@Composable
private fun FormFieldRow(value: String, onChange: (String) -> Unit, placeholder: String, keyboard: KeyboardOptions, modifier: Modifier) {
    val p = LocalStudioPalette.current
    BasicTextField(
        value = value, onValueChange = onChange, singleLine = true, keyboardOptions = keyboard,
        textStyle = TextStyle(color = p.ink, fontSize = 17.sp), cursorBrush = SolidColor(p.accent),
        modifier = modifier.fillMaxWidth().heightIn(min = 48.dp),
        decorationBox = { inner ->
            Box(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) Text(placeholder, color = p.muted.copy(alpha = 0.7f), fontSize = 17.sp)
                inner()
            }
        },
    )
}

@Composable
private fun FormButtonRow(label: String, enabled: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val p = LocalStudioPalette.current
    Box(
        modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(enabled = enabled, onClick = onClick).padding(horizontal = 16.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(label, color = if (enabled) p.accent else p.muted.copy(alpha = 0.6f), fontSize = 17.sp)
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
