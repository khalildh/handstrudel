package com.handstrudel.ui.social.account

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.model.Video
import com.handstrudel.ui.nav.Destination
import com.handstrudel.ui.nav.LocalAppNavigator
import com.handstrudel.ui.social.ProfileActionButton
import com.handstrudel.ui.social.ProfileEyebrow
import com.handstrudel.ui.social.SocialMaterialTheme
import com.handstrudel.ui.social.SocialRefreshBox
import com.handstrudel.ui.social.StudioActionButton
import com.handstrudel.ui.social.auth.SignInSheet
import com.handstrudel.ui.social.feed.CreatorVideoSheet
import com.handstrudel.ui.social.feed.PerformanceStart
import com.handstrudel.ui.social.feed.start
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.theme.LocalStudioPalette
import com.handstrudel.ui.theme.StudioThemePickerSheet
import kotlinx.coroutines.launch

/**
 * iOS `ProfileView` (the Account tab): signed-out pitch, profile loading/retry, or the
 * creator's own profile + portfolio, with the settings menu and account deletion.
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun AccountTab() {
    val social = rememberSocial() ?: return
    val auth = social.auth
    val portfolio = auth.accountPortfolio
    val navigator = LocalAppNavigator.current
    val p = LocalStudioPalette.current
    val scope = rememberCoroutineScope()
    val userId by auth.userId.collectAsState()
    val profile by auth.profile.collectAsState()
    val loadingProfile by auth.isLoadingProfile.collectAsState()
    val needsSetup by auth.needsProfileSetupFlow.collectAsState()
    var playing by remember { mutableStateOf<Video?>(null) }
    var confirmDeleteVideo by remember { mutableStateOf<Video?>(null) }
    var sheet by remember { mutableStateOf<AccountSheet?>(null) }
    var showDeletionFailure by remember { mutableStateOf(false) }
    var showSignIn by remember { mutableStateOf(false) }
    var showEdit by remember { mutableStateOf(false) }
    var deleteError by remember { mutableStateOf(false) }
    val makeMusic = { navigator.select(Destination.Music) }
    fun start(s: PerformanceStart) { playing = null; navigator.start(s) }

    Column(
        Modifier.fillMaxSize().background(p.background).windowInsetsPadding(WindowInsets.statusBars).semantics { testTagsAsResourceId = true },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(Modifier.widthIn(max = 650.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 21.dp).padding(top = 9.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Account", color = p.ink, fontSize = 30.sp, fontFamily = StudioFonts.Serif, modifier = Modifier.weight(1f))
                AccountSettingsMenu(signedIn = userId != null, onOpen = { sheet = it }, onSignOut = { scope.launch { auth.signOut() } })
            }
            val current = profile
            val username = current?.username
            if (current != null && current.id == userId && username != null && !needsSetup) {
                // iOS `.refreshable { await portfolio.load(for: profile.id) }`
                SocialRefreshBox(onRefresh = { portfolio.load(current.id) }, modifier = Modifier.weight(1f).fillMaxWidth()) {
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 21.dp).padding(bottom = 120.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    val counts by portfolio.counts.collectAsState()
                    val videos by portfolio.videos.collectAsState()
                    val hasLoaded by portfolio.hasLoadedPage.collectAsState()
                    val loadingMore by portfolio.isLoadingMore.collectAsState()
                    val failed by portfolio.failed.collectAsState()
                    val more by portfolio.more.collectAsState()
                    LaunchedEffect(current.id) { portfolio.load(current.id) }
                    CreatorProfileHeader(username, current.displayName, current.avatarKey, counts, counts?.likesReceived, counts?.viewsReceived, isOwner = true) {
                        ProfileActionButton("Edit profile", icon = Icons.Filled.Edit, onClick = { showEdit = true }, modifier = Modifier.fillMaxWidth().testTag("edit-profile"))
                    }
                    CreatorPortfolio(
                        videos = videos, loading = !hasLoaded || loadingMore, failed = failed, more = more, isOwner = true,
                        open = { playing = it }, trySound = { navigator.start(PerformanceStart.Preset(it)) },
                        retry = { scope.launch { portfolio.load(current.id) } },
                        loadMore = { scope.launch { portfolio.load(current.id, append = true) } },
                        makeMusic = makeMusic, delete = { confirmDeleteVideo = it },
                    )
                }
                }
            } else if (userId != null && profile == null) {
                Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (loadingProfile) {
                        CircularProgressIndicator(color = p.accent); Text("Loading profile", color = p.muted)
                    } else {
                        Text("Couldn't load your profile.", color = p.muted)
                        ProfileActionButton("Try again", onClick = { scope.launch { auth.refreshProfile() } }, modifier = Modifier.fillMaxWidth())
                    }
                }
            } else {
                Column(
                    Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 21.dp, vertical = 6.dp),
                    verticalArrangement = Arrangement.spacedBy(18.dp),
                ) {
                    val shape = RoundedCornerShape(24.dp)
                    Box(Modifier.fillMaxWidth().clip(shape).border(1.dp, p.border, shape)) {
                        ProfileArtwork()
                        Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            ProfileEyebrow("HANDSTRUDEL / BACKSTAGE")
                            Text("Your music.\nYour stage.", color = p.ink, fontSize = 34.sp, lineHeight = 40.sp, fontFamily = StudioFonts.Serif)
                            Text("Give your performances a home. Share what you play and let others try your sounds.", color = p.muted, fontSize = 15.sp)
                        }
                    }
                    StudioActionButton(if (needsSetup) "Finish setting up" else "Sign in", onClick = { showSignIn = true }, modifier = Modifier.testTag("account-sign-in"))
                    ProfileActionButton("Make music as a guest", onClick = makeMusic, modifier = Modifier.fillMaxWidth())
                    Spacer(Modifier.height(100.dp))
                }
            }
        }
    }

    if (showSignIn) SignInSheet(onDismiss = { showSignIn = false })
    if (showEdit) EditProfileSheet(onDismiss = { showEdit = false })
    when (sheet) {
        AccountSheet.APPEARANCE -> StudioThemePickerSheet(onDismiss = { sheet = null })
        AccountSheet.USAGE_ANALYTICS -> com.handstrudel.ui.settings.UsageAnalyticsScreen(onDismiss = { sheet = null })
        AccountSheet.BLOCKED -> BlockedUsersScreen(onDismiss = { sheet = null })
        AccountSheet.DELETE_ACCOUNT -> DeleteAccountDialog(onDismiss = { sheet = null }, onConfirm = {
            sheet = null
            scope.launch {
                if (auth.deleteAccount() == com.handstrudel.social.AuthManager.AccountDeletionResult.UNCONFIRMED) showDeletionFailure = true
            }
        })
        null -> Unit
    }
    if (showDeletionFailure) AccountDeletionUnconfirmedDialog { showDeletionFailure = false }
    playing?.let { video ->
        CreatorVideoSheet(video, onDismiss = { playing = null }, allowsSharing = video.hidden != true,
            playlist = portfolio.videos.collectAsState().value,
            onPlayAlong = { start(PerformanceStart.Backing(it)) }, onTrySound = { start(PerformanceStart.Preset(it)) })
    }
    SocialMaterialTheme {
        confirmDeleteVideo?.let { video ->
            AlertDialog(onDismissRequest = { confirmDeleteVideo = null }, title = { Text("Delete this post?") },
                confirmButton = {
                    TextButton(onClick = {
                        confirmDeleteVideo = null
                        val uid = auth.userId.value ?: return@TextButton
                        if (video.userId != uid) return@TextButton
                        scope.launch {
                            try {
                                social.feed.deleteVideo(video.id)
                                portfolio.remove(video.id, uid)
                                portfolio.load(uid)
                            } catch (e: Exception) { deleteError = true }
                        }
                    }, modifier = Modifier.testTag("confirm-delete-post")) { Text("Delete", color = p.recording) }
                },
                dismissButton = { TextButton(onClick = { confirmDeleteVideo = null }) { Text("Cancel") } })
        }
        if (deleteError) {
            AlertDialog(onDismissRequest = { deleteError = false }, title = { Text("Couldn't delete this post") },
                confirmButton = { TextButton(onClick = { deleteError = false }) { Text("OK") } })
        }
    }
}
