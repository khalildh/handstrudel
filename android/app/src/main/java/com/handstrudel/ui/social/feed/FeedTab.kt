package com.handstrudel.ui.social.feed

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Fullscreen
import androidx.compose.material.icons.filled.FullscreenExit
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.PlayCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import com.handstrudel.app.LocalAppServices
import com.handstrudel.social.data.FeedNavigation
import com.handstrudel.social.data.SocialException
import com.handstrudel.social.data.UnavailableException
import com.handstrudel.social.model.ReportReason
import com.handstrudel.social.model.Video
import com.handstrudel.social.model.WeeklyChallenge
import com.handstrudel.ui.nav.Destination
import com.handstrudel.ui.nav.LocalAppNavigator
import com.handstrudel.ui.social.FeedVideoIcon
import com.handstrudel.ui.social.SocialMaterialTheme
import com.handstrudel.ui.social.SocialToast
import com.handstrudel.ui.social.StudioActionButton
import com.handstrudel.ui.social.auth.SignInSheet
import com.handstrudel.ui.social.comments.CommentsSheet
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID
import kotlin.math.abs

/**
 * iOS `FeedView`: the full-screen, vertically paged feed of public posts.
 * Browsable signed out; liking, following, reporting and blocking need an account.
 * Always composed while social is configured (so the selected clip warms up);
 * [isActive] is true when it is the visible tab with no session running.
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalComposeUiApi::class)
@Composable
fun FeedTab(isActive: Boolean, onFullscreenChanged: (Boolean) -> Unit, tabBar: @Composable (overVideo: Boolean) -> Unit) {
    val social = rememberSocial() ?: return
    val auth = social.auth
    val services = LocalAppServices.current
    val navigator = LocalAppNavigator.current
    val p = LocalStudioPalette.current
    val context = LocalContext.current
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current
    val lifecycle by lifecycleOwner.lifecycle.currentStateAsState()
    val resumed = lifecycle.isAtLeast(Lifecycle.State.RESUMED)

    val model = remember { FeedModel(social.feed) }
    val pool = remember { FeedPlayerPool(context.applicationContext, scope, social.http, social.feed) }
    DisposableEffect(Unit) { onDispose { pool.releaseAll() } }
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_STOP) pool.releaseAll() }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    val generation by pool.generation.collectAsState()

    val userId by auth.userId.collectAsState()
    val videos by model.videos.collectAsState()
    val current by model.current.collectAsState()
    val mode by model.mode.collectAsState()
    val loading by model.loading.collectAsState()
    val error by model.error.collectAsState()
    val following by model.following.collectAsState()
    val savedIds by model.savedIds.collectAsState()
    val audioIds by model.audioDownloadIds.collectAsState()
    val engagement by model.engagement.collectAsState()
    val confirmedNoFollows by model.confirmedNoFollows.collectAsState()
    val muted by services.prefs.feedMuted.collectAsState()

    var showSignIn by remember { mutableStateOf(false) }
    var reporting by remember { mutableStateOf<Video?>(null) }
    var commenting by remember { mutableStateOf<Video?>(null) }
    var lastCommentVideo by remember { mutableStateOf<UUID?>(null) }
    var toast by remember { mutableStateOf<String?>(null) }
    var showActivity by remember { mutableStateOf(false) }
    var unreadActivity by remember { mutableStateOf(false) }
    var creatorVideo by remember { mutableStateOf<Video?>(null) }
    var sourceVideo by remember { mutableStateOf<Video?>(null) }
    var soundVideo by remember { mutableStateOf<Video?>(null) }
    var remixVideo by remember { mutableStateOf<Video?>(null) }
    var showSaved by remember { mutableStateOf(false) }
    var showSearch by remember { mutableStateOf(false) }
    var challenge by remember { mutableStateOf<WeeklyChallenge?>(null) }
    var openChallenge by remember { mutableStateOf<WeeklyChallenge?>(null) }
    var pendingBookmark by remember { mutableStateOf<Video?>(null) }
    var preparingAudio by remember { mutableStateOf(false) }
    var audioMessage by remember { mutableStateOf<String?>(null) }
    var deleting by remember { mutableStateOf<Video?>(null) }
    var confirmingAudioPermission by remember { mutableStateOf<Video?>(null) }
    var feedMenu by remember { mutableStateOf(false) }
    var isFullscreen by rememberSaveable { mutableStateOf(false) }
    var showsFullscreenControls by remember { mutableStateOf(true) }
    var headerHeight by remember { mutableStateOf(100.dp) }
    var navigationHeight by remember { mutableStateOf(66.dp) }

    val hasVideos = videos.isNotEmpty()
    val signedIn = userId != null
    val allowsFeedPlayback = isActive && resumed && commenting == null && !showActivity && creatorVideo == null &&
        sourceVideo == null && soundVideo == null && remixVideo == null && !showSaved && !showSearch &&
        openChallenge == null && !showSignIn && reporting == null && deleting == null && confirmingAudioPermission == null && !preparingAudio
    val selectedVideo = videos.getOrNull(current)
    val engagementTarget = if (allowsFeedPlayback && !isFullscreen) selectedVideo?.id else null

    fun show(message: String) {
        toast = message
        scope.launch { delay(2_500); if (toast == message) toast = null }
    }

    fun requireSignIn(action: (UUID) -> Unit) {
        val uid = auth.userId.value
        if (uid == null || auth.needsProfileSetup) { showSignIn = true; return }
        action(uid)
    }

    fun act(op: suspend (UUID) -> Unit) = requireSignIn { uid ->
        scope.launch {
            try { op(uid) } catch (e: CancellationException) { throw e } catch (e: Exception) {
                show("Couldn't do that — ${e.message ?: "try again."}")
            }
        }
    }

    fun closeSheets() {
        showSearch = false; showSaved = false; openChallenge = null; remixVideo = null; commenting = null
        showActivity = false; creatorVideo = null; sourceVideo = null; soundVideo = null
    }

    /** iOS `resumePerformance`: close the sheets, then hand off to Music. */
    fun startPerformance(start: PerformanceStart) {
        closeSheets()
        navigator.start(start)
    }

    // ---- Pager ---------------------------------------------------------------------
    val pagerState = rememberPagerState { videos.size }
    fun movePage(by: Int): Boolean {
        val target = FeedNavigation.destination(model.current.value, by, model.videos.value.size) ?: return false
        model.current.value = target
        scope.launch { pagerState.scrollToPage(target) }
        return true
    }
    fun advanceAfterClip(id: UUID): Boolean =
        model.videos.value.getOrNull(model.current.value)?.id == id && movePage(1)

    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }.collect { page ->
            if (page in model.videos.value.indices && page != model.current.value) model.current.value = page
        }
    }
    LaunchedEffect(current, videos.size) {
        if (current in videos.indices && pagerState.currentPage != current && !pagerState.isScrollInProgress) pagerState.scrollToPage(current)
        model.loadMore()
    }
    LaunchedEffect(pagerState) { snapshotFlow { pagerState.isScrollInProgress }.collect { pool.isPaging = it } }
    val edgeSwipes = remember(pagerState) {
        object : NestedScrollConnection {
            var overscroll = 0f
            override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
                if (source == NestedScrollSource.UserInput) overscroll += available.y
                return Offset.Zero
            }
            override suspend fun onPreFling(available: Velocity): Velocity {
                val travel = overscroll
                overscroll = 0f
                // Rubber-banding past either edge picks a random different clip (iOS onBoundary).
                if (abs(travel) >= with(density) { 48.dp.toPx() }) movePage(if (travel < 0) 1 else -1)
                return Velocity.Zero
            }
        }
    }

    // ---- Loading ---------------------------------------------------------------------
    suspend fun refreshBadge() {
        val viewer = auth.userId.value ?: run { unreadActivity = false; return }
        val unread = runCatching { social.feed.hasUnreadActivity() }.getOrDefault(false)
        if (auth.userId.value == viewer) unreadActivity = unread
    }

    LaunchedEffect(userId, mode) {
        model.refresh(userId)
        refreshBadge()
    }
    LaunchedEffect(engagementTarget) { engagementTarget?.let { model.refreshEngagement(it) } }
    LaunchedEffect(userId, isActive && resumed) {
        challenge = null
        if (!isActive || !resumed) return@LaunchedEffect
        challenge = runCatching { social.feed.weeklyChallenge() }.getOrNull()
    }
    LaunchedEffect(isActive && resumed && signedIn && !showActivity) {
        if (isActive && resumed && signedIn && !showActivity) refreshBadge()
    }
    var lastUser by remember { mutableStateOf(userId) }
    LaunchedEffect(userId) {
        if (lastUser != userId) {
            unreadActivity = false; showSaved = false; openChallenge = null
            if (userId == null && model.followingOnly) model.mode.value = FeedMode.DISCOVER
        }
        lastUser = userId
    }
    LaunchedEffect(isFullscreen) {
        if (isFullscreen) showsFullscreenControls = true
        onFullscreenChanged(isFullscreen)
    }
    BackHandler(enabled = isActive && isFullscreen) { isFullscreen = false }

    // ---- Actions -----------------------------------------------------------------------
    fun writeBookmark(video: Video, user: UUID, explicitlySave: Boolean = false) {
        scope.launch {
            try {
                model.toggleBookmark(video.id, user, explicitlySave)?.let { saved ->
                    show(if (saved) "Saved privately." else "Removed from Saved.")
                    model.refreshEngagement(video.id)
                }
            } catch (e: UnavailableException) { show(e.message ?: "") } catch (e: CancellationException) { throw e } catch (e: Exception) {
                show("Couldn't update Saved. Try again.")
            }
        }
    }

    fun toggleBookmark(video: Video) {
        val uid = auth.userId.value
        if (uid == null || auth.needsProfileSetup) { pendingBookmark = video; showSignIn = true; return }
        writeBookmark(video, uid)
    }

    fun toggleRepost(video: Video) = requireSignIn { uid ->
        scope.launch {
            try {
                model.toggleRepost(video, uid)?.let { show(if (it) "Reposted to your followers." else "Repost removed.") }
            } catch (e: UnavailableException) { show(e.message ?: "") } catch (e: CancellationException) { throw e } catch (e: Exception) {
                show("Couldn't update your repost. Try again.")
            }
        }
    }

    fun changeAudioPermission(video: Video) {
        scope.launch {
            try {
                show(if (model.toggleAudioPermission(video.id)) "Audio downloads allowed." else "Audio downloads turned off.")
            } catch (e: CancellationException) { throw e } catch (e: Exception) { show("Couldn't change audio downloads. Try again.") }
        }
    }

    fun downloadAudio(video: Video) {
        if (preparingAudio) return
        preparingAudio = true
        scope.launch {
            try {
                if (video.id !in social.feed.audioDownloadsAllowed(listOf(video.id))) {
                    throw SocialException("The creator hasn't allowed audio downloads for this clip.")
                }
                PerformanceAudio.share(context, PerformanceAudio.export(context, social.http, video))
            } catch (e: SocialException) { audioMessage = e.message } catch (e: CancellationException) { throw e } catch (e: Exception) {
                audioMessage = "Couldn't prepare the audio. Try again."
            } finally { preparingAudio = false }
        }
    }

    fun openSource(id: UUID) {
        scope.launch {
            try {
                val video = social.feed.video(id)
                if (video == null) show("The original performance is unavailable.") else sourceVideo = video
            } catch (e: CancellationException) { throw e } catch (e: Exception) { show("Couldn't open the original performance.") }
        }
    }

    // ---- Selection: one visit restarts the clip -------------------------------------------
    val currentClip = selectedVideo?.let { video -> remember(video.id, generation) { pool.acquire(video) } }
    DisposableEffect(currentClip) { onDispose { currentClip?.let(pool::release) } }
    LaunchedEffect(selectedVideo?.id) { currentClip?.prepareForVisit() }

    // ---- Layout --------------------------------------------------------------------------
    BoxWithConstraints(
        Modifier.fillMaxSize().background(if (hasVideos || isFullscreen) Color.Black else p.background)
            .semantics { testTagsAsResourceId = true },
    ) {
        val viewportHeight = maxHeight
        if (hasVideos) {
            VerticalPager(
                state = pagerState,
                beyondViewportPageCount = 1,
                key = { videos.getOrNull(it)?.id ?: it },
                modifier = Modifier.fillMaxSize().nestedScroll(edgeSwipes).testTag("feed-video-viewport"),
            ) { page ->
                val video = videos.getOrNull(page) ?: return@VerticalPager
                val clip = remember(video.id, generation) { pool.acquire(video) }
                DisposableEffect(clip) { onDispose { pool.release(clip) } }
                val isCurrent = page == current
                SideEffect {
                    clip.onEnded = { advanceAfterClip(video.id) }
                    clip.onViewCount = { id, count -> model.recordViewCount(count, id) }
                    clip.configure(isCurrent = isCurrent, allowed = allowsFeedPlayback, muted = muted)
                }
                FeedCell(
                    video = video, clip = clip, isCurrent = isCurrent, isFullscreen = isFullscreen,
                    showsFullscreenControls = showsFullscreenControls,
                    onToggleFullscreenControls = { showsFullscreenControls = !showsFullscreenControls },
                    engagement = engagement[video.id],
                    bottomInset = navigationHeight + FeedProgressStripHeight + 3.dp,
                    isMine = video.userId == userId, isFollowing = video.userId in following,
                    follow = { act { model.toggleFollow(video.userId, it) } },
                    creator = { creatorVideo = video },
                    showSound = { soundVideo = video },
                    source = ::openSource,
                )
            }
        } else {
            EmptyState(
                loading = loading, error = error, followingOnly = mode == FeedMode.FOLLOWING, signedIn = signedIn,
                confirmedNoFollows = confirmedNoFollows,
                onSignIn = { showSignIn = true }, onBrowseDiscover = { model.mode.value = FeedMode.DISCOVER },
                onMakeMusic = { navigator.select(Destination.Music) },
                onRefresh = { scope.launch { model.refresh(auth.userId.value) } },
                modifier = Modifier.padding(top = headerHeight, bottom = navigationHeight),
            )
        }

        if (isActive && !isFullscreen && selectedVideo != null) {
            val railHeight = maxOf(44.dp, viewportHeight - headerHeight - navigationHeight - FeedProgressStripHeight - 12.dp)
            FeedActionRail(
                video = selectedVideo, clip = currentClip, engagement = engagement[selectedVideo.id], maxHeight = railHeight,
                isMine = selectedVideo.userId == userId, isSaved = selectedVideo.id in savedIds,
                canDownloadAudio = selectedVideo.id in audioIds,
                canChangeAudioPermission = selectedVideo.userId == userId && selectedVideo.sourceVideoId == null,
                actions = FeedRailActions(
                    like = { act { model.toggleLike(selectedVideo, it) } },
                    comments = { lastCommentVideo = selectedVideo.id; commenting = selectedVideo },
                    showRemixes = { remixVideo = selectedVideo },
                    repost = { toggleRepost(selectedVideo) },
                    share = { VideoShareSheet.share(context, selectedVideo) { scope.launch { runCatching { social.feed.recordShare(selectedVideo.id) }; model.refreshEngagement(selectedVideo.id) } } },
                    bookmark = { toggleBookmark(selectedVideo) },
                    downloadAudio = { downloadAudio(selectedVideo) },
                    changeAudioPermission = {
                        if (selectedVideo.id in audioIds) changeAudioPermission(selectedVideo) else confirmingAudioPermission = selectedVideo
                    },
                    revokeBacking = {
                        act {
                            social.feed.stopAllowingBacking(selectedVideo.id)
                            model.refreshVideoControls(selectedVideo.id)
                            show("New play-along posts are off.")
                        }
                    },
                    delete = { deleting = selectedVideo },
                    report = { requireSignIn { reporting = selectedVideo } },
                    block = { act { model.block(selectedVideo.userId, it); show("Blocked @${selectedVideo.username ?: "user"}") } },
                ),
                modifier = Modifier.align(Alignment.BottomEnd)
                    .padding(end = 15.dp, bottom = navigationHeight + FeedProgressStripHeight + 3.dp),
            )
        }

        if (isActive && currentClip != null && (!isFullscreen || showsFullscreenControls)) {
            val swipe: (Float) -> Unit = { dy -> movePage(if (dy > 0) -1 else 1) }
            if (isFullscreen) {
                PlaybackControls(currentClip, showsPause = true, muted = muted, toggleMute = { services.prefs.setFeedMuted(!muted) },
                    durationHint = selectedVideo.durationS, onVerticalSwipe = swipe,
                    modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(horizontal = 15.dp).padding(bottom = 3.dp))
            } else {
                FeedProgressStrip(currentClip, selectedVideo.durationS, onVerticalSwipe = swipe,
                    modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(horizontal = 15.dp).padding(bottom = navigationHeight + 3.dp))
            }
        }

        if (isActive) {
            val ink = if (hasVideos || isFullscreen) Color.White else p.ink
            Column(
                Modifier.align(Alignment.TopCenter).fillMaxWidth()
                    .then(if (hasVideos && !isFullscreen) Modifier.background(Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.8f), Color.Black.copy(alpha = 0.38f), Color.Transparent))) else Modifier)
                    .windowInsetsPadding(WindowInsets.statusBars)
                    .padding(horizontal = 16.dp).padding(top = 7.dp)
                    .onSizeChanged { headerHeight = with(density) { it.height.toDp() } },
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (!isFullscreen) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box {
                            Row(
                                Modifier.heightIn(min = 44.dp).clickable { feedMenu = true }
                                    .semantics(mergeDescendants = true) { contentDescription = "Feed options"; stateDescription = mode.title }
                                    .testTag("feed-options"),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(if (mode == FeedMode.DISCOVER) "Feed" else mode.title, color = ink, fontSize = 33.sp, fontFamily = FontFamily.Serif, maxLines = 1)
                                Spacer(Modifier.size(7.dp))
                                Icon(Icons.Filled.KeyboardArrowDown, null, tint = ink, modifier = Modifier.size(16.dp))
                            }
                            SocialMaterialTheme {
                                DropdownMenu(expanded = feedMenu, onDismissRequest = { feedMenu = false }) {
                                    Text("Show", color = p.muted, fontSize = 12.sp, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp))
                                    FeedMode.entries.forEach { option ->
                                        DropdownMenuItem(
                                            text = { Text(option.title) },
                                            leadingIcon = { RadioButton(selected = option == mode, onClick = null) },
                                            onClick = { feedMenu = false; model.mode.value = option },
                                            modifier = Modifier.testTag("feed-mode-${option.title.lowercase()}"),
                                        )
                                    }
                                    HorizontalDivider()
                                    DropdownMenuItem(
                                        text = { Text("Refresh feed") }, enabled = !loading,
                                        leadingIcon = { Icon(Icons.Filled.Refresh, null) },
                                        onClick = { feedMenu = false; scope.launch { model.refresh(auth.userId.value) } },
                                    )
                                }
                            }
                        }
                        Spacer(Modifier.weight(1f))
                        HeaderIcon(Icons.Filled.Search, "Search posts", "search-posts", ink) { showSearch = true }
                        HeaderIcon(Icons.Outlined.BookmarkBorder, "Saved performances", "saved-performances", ink) { requireSignIn { showSaved = true } }
                        Box {
                            HeaderIcon(Icons.Outlined.Notifications, if (unreadActivity) "Notifications, unread" else "Notifications", "activity-inbox", ink) {
                                requireSignIn { showActivity = true }
                            }
                            if (unreadActivity) Box(Modifier.align(Alignment.TopEnd).padding(9.dp).size(7.dp).clip(CircleShape).background(p.accent))
                        }
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    val c = challenge
                    if (!isFullscreen && c != null && mode != FeedMode.FOLLOWING) {
                        Box(Modifier.weight(1f, fill = false)) { WeeklyChallengeBanner(c, hasVideos) { openChallenge = c } }
                    }
                    Spacer(Modifier.weight(1f))
                    if (hasVideos || isFullscreen) {
                        if (!isFullscreen) {
                            Box(Modifier.clickable { services.prefs.setFeedMuted(!muted) }.testTag("feed-mute")) {
                                FeedVideoIcon(if (muted) Icons.AutoMirrored.Filled.VolumeOff else Icons.AutoMirrored.Filled.VolumeUp, if (muted) "Unmute" else "Mute")
                            }
                        }
                        Box(Modifier.clickable { isFullscreen = !isFullscreen }.testTag("feed-fullscreen")) {
                            FeedVideoIcon(if (isFullscreen) Icons.Filled.FullscreenExit else Icons.Filled.Fullscreen, if (isFullscreen) "Exit full screen" else "Full screen")
                        }
                    }
                }
            }
        }

        if (isActive && !isFullscreen) {
            Box(Modifier.align(Alignment.BottomCenter).onSizeChanged { navigationHeight = with(density) { it.height.toDp() } }) {
                tabBar(hasVideos)
            }
        }
        if (isActive) SocialToast(toast ?: if (preparingAudio) "Preparing audio…" else null, topPadding = (headerHeight.value + 4).toInt())
    }

    // ---- Sheets ------------------------------------------------------------------------
    if (showSignIn) SignInSheet(onDismiss = {
        showSignIn = false
        val video = pendingBookmark
        pendingBookmark = null
        val uid = auth.userId.value
        if (video != null && uid != null && !auth.needsProfileSetup) writeBookmark(video, uid, explicitlySave = true)
    }, reason = "Sign in to save performances and join the community.")
    if (showSearch) PostSearchScreen(onDismiss = { showSearch = false }, onStart = ::startPerformance)
    if (showSaved) PerformanceLibraryScreen(LibraryKind.Saved, onDismiss = { showSaved = false }, onRemove = model::removedBookmark, onStart = ::startPerformance)
    openChallenge?.let { PerformanceLibraryScreen(LibraryKind.Challenge(it), onDismiss = { openChallenge = null }, onStart = ::startPerformance) }
    remixVideo?.let { PerformanceLibraryScreen(LibraryKind.Remixes(it), onDismiss = { remixVideo = null }, onStart = ::startPerformance) }
    commenting?.let { video ->
        CommentsSheet(video, onDismiss = {
            commenting = null
            lastCommentVideo?.let { id -> scope.launch { model.refreshVideoControls(id) } }
        }, onBlock = { author ->
            model.removeBlockedAuthor(author)
            if (author == video.userId) commenting = null
        })
    }
    if (showActivity) ActivityInboxScreen(onDismiss = { showActivity = false; scope.launch { refreshBadge() } }, onStart = ::startPerformance)
    creatorVideo?.let { video ->
        PublicCreatorScreen(video.userId, onDismiss = { creatorVideo = null },
            onFollowChange = { scope.launch { model.refresh(auth.userId.value) } }, onStart = ::startPerformance)
    }
    sourceVideo?.let { video ->
        CreatorVideoSheet(video, onDismiss = { sourceVideo = null },
            onPlayAlong = { startPerformance(PerformanceStart.Backing(it)) },
            onTrySound = { startPerformance(PerformanceStart.Preset(it)) })
    }
    soundVideo?.let { video -> FeedSoundSheet(video, onDismiss = { soundVideo = null }, onStart = ::startPerformance) }

    SocialMaterialTheme {
        deleting?.let { video ->
            AlertDialog(onDismissRequest = { deleting = null }, title = { Text("Delete this post?") },
                confirmButton = {
                    TextButton(onClick = {
                        deleting = null
                        scope.launch { runCatching { model.delete(video) }.onFailure { show("Couldn't delete this post.") } }
                    }) { Text("Delete", color = p.recording) }
                },
                dismissButton = { TextButton(onClick = { deleting = null }) { Text("Cancel") } })
        }
        confirmingAudioPermission?.let { video ->
            AlertDialog(onDismissRequest = { confirmingAudioPermission = null }, title = { Text("Let anyone download this clip's audio?") },
                text = { Text("This includes any voice in the clip. Only allow downloads if you have permission to share all of the audio.") },
                confirmButton = { TextButton(onClick = { confirmingAudioPermission = null; changeAudioPermission(video) }) { Text("Allow audio downloads") } },
                dismissButton = { TextButton(onClick = { confirmingAudioPermission = null }) { Text("Cancel") } })
        }
        reporting?.let { video ->
            AlertDialog(onDismissRequest = { reporting = null }, title = { Text("Report this post") },
                text = {
                    Column {
                        Text("Reports are anonymous. Posts with several reports are hidden while we review them.")
                        ReportReason.entries.forEach { reason ->
                            TextButton(onClick = {
                                reporting = null
                                act { model.report(video, reason, it); show("Thanks — we'll review it within 24 hours") }
                            }, modifier = Modifier.fillMaxWidth().testTag("report-${reason.name.lowercase()}")) { Text(reason.raw) }
                        }
                    }
                },
                confirmButton = {}, dismissButton = { TextButton(onClick = { reporting = null }) { Text("Cancel") } })
        }
        audioMessage?.let { message ->
            AlertDialog(onDismissRequest = { audioMessage = null }, title = { Text("Download audio") }, text = { Text(message) },
                confirmButton = { TextButton(onClick = { audioMessage = null }) { Text("OK") } })
        }
    }
}

@Composable
private fun HeaderIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, tag: String, tint: Color, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp).clickable(onClick = onClick).semantics { contentDescription = label }.testTag(tag),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = tint, modifier = Modifier.size(22.dp)) }
}

@Composable
private fun EmptyState(
    loading: Boolean, error: String?, followingOnly: Boolean, signedIn: Boolean, confirmedNoFollows: Boolean,
    onSignIn: () -> Unit, onBrowseDiscover: () -> Unit, onMakeMusic: () -> Unit, onRefresh: () -> Unit, modifier: Modifier,
) {
    val p = LocalStudioPalette.current
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(Modifier.widthIn(max = 360.dp).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (loading) {
                CircularProgressIndicator(color = p.accent)
                Text("Loading videos", color = p.muted)
            } else {
                Icon(Icons.Outlined.PlayCircle, null, tint = p.accent, modifier = Modifier.size(40.dp))
                val title = when {
                    error != null -> error
                    !followingOnly -> "No performances yet"
                    signedIn && confirmedNoFollows -> "You aren't following any creators yet"
                    else -> "No performances from creators you follow yet"
                }
                Text(title, color = p.ink, fontWeight = FontWeight.Bold, fontSize = 20.sp, textAlign = TextAlign.Center)
                if (followingOnly) {
                    if (!signedIn) {
                        StudioActionButton("Sign in to follow creators", onClick = onSignIn)
                    } else {
                        if (error == null) {
                            Text(
                                if (confirmedNoFollows) "Follow a creator in Discover or Latest to see their posts here."
                                else "New public posts from creators you follow will appear here.",
                                color = p.muted, fontSize = 15.sp, textAlign = TextAlign.Center,
                            )
                        }
                        StudioActionButton("Browse Discover", onClick = onBrowseDiscover)
                    }
                } else if (error == null) {
                    StudioActionButton("Make the first one", onClick = onMakeMusic)
                }
                TextButton(onClick = onRefresh, modifier = Modifier.heightIn(min = 44.dp)) {
                    Text(if (error == null) "Refresh" else "Try again", color = p.accent)
                }
            }
        }
    }
}
