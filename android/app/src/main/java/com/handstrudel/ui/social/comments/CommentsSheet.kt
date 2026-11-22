package com.handstrudel.ui.social.comments

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.handstrudel.social.data.SocialException
import com.handstrudel.social.model.CommentReportReason
import com.handstrudel.social.model.Video
import com.handstrudel.social.model.VideoComment
import com.handstrudel.ui.social.SocialMaterialTheme
import com.handstrudel.ui.social.StudioActionButton
import com.handstrudel.ui.social.auth.SignInSheet
import com.handstrudel.ui.social.compactCount
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.social.relativeTime
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.util.UUID

private sealed interface CommentAction {
    val comment: VideoComment
    data class Report(override val comment: VideoComment) : CommentAction
    data class Delete(override val comment: VideoComment) : CommentAction
    data class Block(override val comment: VideoComment) : CommentAction

    val title: String
        get() = when (this) {
            is Report -> "Report this comment"
            is Delete -> "Delete this comment?"
            is Block -> "Block @${comment.username}?"
        }
}

/**
 * iOS `CommentsView`: threaded comments (one reply level), likes, report/delete/block,
 * owner "Manage comments", composer with the 300-scalar limit, deep-linked comment reveal.
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun CommentsSheet(
    video: Video,
    onDismiss: () -> Unit,
    targetComment: UUID? = null,
    onBlock: (UUID) -> Unit = {},
) {
    val social = rememberSocial() ?: return
    val auth = social.auth
    val feed = social.feed
    val p = LocalStudioPalette.current
    val scope = rememberCoroutineScope()
    val userId by auth.userId.collectAsState()
    val needsSetup by auth.needsProfileSetupFlow.collectAsState()
    val canPost = userId != null && !needsSetup
    val isOwner = userId == video.userId

    val roots = remember { mutableStateListOf<VideoComment>() }
    val replies = remember { mutableStateMapOf<UUID, List<VideoComment>>() }
    val replyOffsets = remember { mutableStateMapOf<UUID, Int>() }
    var replyTarget by remember { mutableStateOf<VideoComment?>(null) }
    var draft by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var showSignIn by remember { mutableStateOf(false) }
    var action by remember { mutableStateOf<CommentAction?>(null) }
    var busy by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(true) }
    var hasMore by remember { mutableStateOf(false) }
    var rootOffset by remember { mutableStateOf(0) }
    var enabled by remember { mutableStateOf(video.commentsEnabled ?: false) }
    val pendingLikes = remember { mutableStateListOf<UUID>() }
    var highlighted by remember { mutableStateOf<UUID?>(null) }
    var ownerMenu by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    val composerFocus = remember { FocusRequester() }

    suspend fun reload() {
        loading = true
        errorMessage = null
        try {
            val fresh = feed.video(video.id)
            val commentsEnabled = fresh?.commentsEnabled ?: false
            val items = if (commentsEnabled) feed.comments(video.id) else emptyList()
            enabled = commentsEnabled
            roots.clear(); roots.addAll(items)
            rootOffset = items.size
            hasMore = items.size == com.handstrudel.social.data.FeedService.COMMENT_PAGE_SIZE
            replies.clear(); replyOffsets.clear()
            replyTarget = VideoComment.replyTargetAfterRefresh(replyTarget, items)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            errorMessage = "Couldn't load comments. Pull down to try again."
        } finally {
            loading = false
        }
    }

    suspend fun loadReplies(parent: UUID, append: Boolean = false) {
        val prior = if (append) replies[parent].orEmpty() else emptyList()
        val offset = if (append && replies[parent] != null) replyOffsets[parent] ?: 0 else 0
        val items = feed.comments(video.id, parent, offset)
        replyOffsets[parent] = offset + items.size
        val seen = prior.map { it.id }.toSet()
        replies[parent] = prior + items.filter { it.id !in seen }
    }

    suspend fun reveal(id: UUID) {
        try {
            val target = feed.comment(id, video.id)
            if (target == null) { notice = "This comment is no longer available."; return }
            val parent = target.parentId
            if (parent != null) {
                if (roots.none { it.id == parent }) feed.comment(parent, video.id)?.let { roots.add(it) }
                loadReplies(parent)
                if (replies[parent]?.any { it.id == id } == false) replies[parent] = replies[parent].orEmpty() + target
            } else if (roots.none { it.id == id }) {
                roots.add(target)
            }
            highlighted = id
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            notice = "Couldn't open that comment. Pull down to refresh."
        }
    }

    suspend fun refreshThread(around: VideoComment) {
        val parent = around.parentId
        if (parent != null) {
            replies[parent] = replies[parent].orEmpty().filter { it.id != around.id }
        } else {
            roots.removeAll { it.id == around.id }
            replies.remove(around.id)
            if (replyTarget?.id == around.id) replyTarget = null
        }
        reload()
        if (parent != null && roots.any { it.id == parent }) runCatching { loadReplies(parent) }
    }

    fun perform(work: suspend () -> Unit) {
        if (busy) return
        busy = true
        errorMessage = null
        notice = null
        scope.launch {
            try { work() } catch (e: CancellationException) { throw e } catch (e: Exception) {
                errorMessage = (e as? SocialException)?.message ?: "Couldn't complete that action. Try again."
            } finally { busy = false }
        }
    }

    fun toggleLike(comment: VideoComment) {
        val viewer = userId
        if (!enabled || viewer == null) { showSignIn = true; return }
        if (comment.id in pendingLikes) return
        pendingLikes.add(comment.id)
        val liked = comment.likedByMe != true
        errorMessage = null
        scope.launch {
            try {
                feed.setCommentLiked(liked, comment.id, viewer)
                if (auth.userId.value != viewer) return@launch
                // Update the displayed row, which may have refreshed while the request was in flight.
                val parent = comment.parentId
                val inReplies = parent?.let { replies[it] }?.indexOfFirst { it.id == comment.id } ?: -1
                if (parent != null && inReplies >= 0) {
                    replies[parent] = replies[parent]!!.mapIndexed { i, c -> if (i == inReplies) c.applyingLike(liked) else c }
                } else {
                    val index = roots.indexOfFirst { it.id == comment.id }
                    if (index >= 0) roots[index] = roots[index].applyingLike(liked)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (auth.userId.value == viewer) errorMessage = (e as? SocialException)?.message ?: "Couldn't update this like. Try again."
            } finally {
                pendingLikes.remove(comment.id)
            }
        }
    }

    fun submit() {
        if (!canPost || !VideoComment.isValidBody(draft)) return
        val body = VideoComment.trimmed(draft)
        val target = replyTarget
        perform {
            feed.addComment(video.id, target?.id, body)
            draft = ""
            replyTarget = null
            reload()
            if (target != null && roots.any { it.id == target.id }) runCatching { loadReplies(target.id) }
        }
    }

    LaunchedEffect(userId) {
        roots.clear(); replies.clear()
        reload()
        targetComment?.let { reveal(it) }
    }
    LaunchedEffect(highlighted) {
        val id = highlighted ?: return@LaunchedEffect
        var index = 0
        for (root in roots) {
            if (root.id == id) break
            index++
            val r = replies[root.id].orEmpty()
            val inner = r.indexOfFirst { it.id == id }
            if (inner >= 0) { index += inner; break }
            index += r.size + 1
        }
        runCatching { listState.animateScrollToItem(index.coerceAtLeast(0)) }
    }

    Dialog(
        onDismissRequest = { if (!busy) onDismiss() },
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        val keyboard = com.handstrudel.ui.social.DialogResizesForKeyboard()
        SocialMaterialTheme {
            Column(
                Modifier.fillMaxSize().background(p.background).windowInsetsPadding(WindowInsets.statusBars)
                    .windowInsetsPadding(WindowInsets.navigationBars).padding(bottom = keyboard).semantics { testTagsAsResourceId = true },
            ) {
                // Header
                Row(Modifier.fillMaxWidth().padding(start = 18.dp, end = 10.dp, top = 16.dp, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Comments", color = p.ink, fontSize = 22.sp, fontFamily = androidx.compose.ui.text.font.FontFamily.Serif)
                        video.username?.let { Text("Performance by @$it", color = p.muted, fontSize = 12.sp) }
                    }
                    if (isOwner) {
                        Box {
                            IconButton(onClick = { ownerMenu = true }, enabled = !busy, modifier = Modifier.semantics { contentDescription = "Manage comments" }) {
                                Icon(Icons.Filled.MoreHoriz, null, tint = p.ink)
                            }
                            DropdownMenu(expanded = ownerMenu, onDismissRequest = { ownerMenu = false }) {
                                DropdownMenuItem(text = { Text(if (enabled) "Turn off comments" else "Turn on comments") }, onClick = {
                                    ownerMenu = false
                                    val uid = userId ?: return@DropdownMenuItem
                                    perform {
                                        feed.setCommentsEnabled(!enabled, video.id, uid)
                                        enabled = !enabled
                                        roots.clear(); replies.clear()
                                        reload()
                                    }
                                })
                            }
                        }
                    }
                    IconButton(onClick = onDismiss, enabled = !busy, modifier = Modifier.semantics { contentDescription = "Close comments" }) {
                        Box(Modifier.size(36.dp).clip(CircleShape).background(p.surface), contentAlignment = Alignment.Center) {
                            Icon(Icons.Filled.Close, null, tint = p.ink, modifier = Modifier.size(16.dp))
                        }
                    }
                }
                HorizontalDivider(color = p.border)
                errorMessage?.let { msg ->
                    Row(Modifier.fillMaxWidth().background(p.surface).padding(horizontal = 18.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(msg, color = p.ink, fontSize = 13.sp, modifier = Modifier.weight(1f))
                        IconButton(onClick = { errorMessage = null }, modifier = Modifier.semantics { contentDescription = "Dismiss" }) {
                            Icon(Icons.Filled.Close, null, tint = p.muted, modifier = Modifier.size(16.dp))
                        }
                    }
                } ?: notice?.let { Text(it, color = p.accent, fontSize = 13.sp, modifier = Modifier.padding(8.dp)) }

                // Thread
                LazyColumn(
                    Modifier.weight(1f).fillMaxWidth().alpha(if (busy) 0.6f else 1f), state = listState,
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    if (!enabled) {
                        item { Empty("Comments are off", "The creator has turned off comments for this performance.") }
                    } else if (roots.isEmpty()) {
                        item {
                            if (loading) Box(Modifier.fillMaxWidth().padding(vertical = 32.dp), contentAlignment = Alignment.Center) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    CircularProgressIndicator(color = p.accent); Spacer(Modifier.size(8.dp)); Text("Loading comments", color = p.muted)
                                }
                            } else if (errorMessage == null) Empty("Start the conversation", "Say what you liked, or ask how they made that sound.")
                        }
                    }
                    for (root in roots.toList()) {
                        item(key = root.id) {
                            CommentRow(root, video, userId, isOwner, highlighted == root.id, pendingLikes.contains(root.id) || loading,
                                onReply = { if (!canPost) showSignIn = true; replyTarget = root; if (canPost) runCatching { composerFocus.requestFocus() } },
                                onLike = { toggleLike(root) },
                                onAction = { a -> if (a is CommentAction.Delete || canPost) action = a else showSignIn = true })
                        }
                        val items = replies[root.id]
                        items?.forEach { reply ->
                            item(key = reply.id) {
                                Box(Modifier.padding(start = 38.dp)) {
                                    CommentRow(reply, video, userId, isOwner, highlighted == reply.id, pendingLikes.contains(reply.id) || loading,
                                        onReply = { if (!canPost) showSignIn = true; replyTarget = root; if (canPost) runCatching { composerFocus.requestFocus() } },
                                        onLike = { toggleLike(reply) },
                                        onAction = { a -> if (a is CommentAction.Delete || canPost) action = a else showSignIn = true })
                                }
                            }
                        }
                        val loaded = items?.size ?: 0
                        if (root.replyCount > loaded) {
                            item(key = "more-${root.id}") {
                                TextButton(onClick = { perform { loadReplies(root.id, append = true) } }, modifier = Modifier.padding(start = 39.dp)) {
                                    Text(if (loaded == 0) "View replies (${root.replyCount})" else "More replies", color = p.accent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        } else if (loaded > 0) {
                            item(key = "hide-${root.id}") {
                                TextButton(onClick = { replies.remove(root.id) }, modifier = Modifier.padding(start = 39.dp)) {
                                    Text("Hide replies", color = p.accent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                    if (hasMore) {
                        item {
                            TextButton(onClick = {
                                perform {
                                    val more = feed.comments(video.id, offset = rootOffset)
                                    rootOffset += more.size
                                    hasMore = more.size == com.handstrudel.social.data.FeedService.COMMENT_PAGE_SIZE
                                    val seen = roots.map { it.id }.toSet()
                                    roots.addAll(more.filter { it.id !in seen })
                                }
                            }) { Text("Load more comments", color = p.accent, fontWeight = FontWeight.SemiBold) }
                        }
                    }
                }

                // Composer
                if (enabled) {
                    HorizontalDivider(color = p.border)
                    Column(Modifier.padding(horizontal = 18.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        replyTarget?.let { target ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Replying to @${target.username}", color = p.muted, fontSize = 12.sp, modifier = Modifier.weight(1f))
                                IconButton(onClick = { replyTarget = null }, modifier = Modifier.semantics { contentDescription = "Cancel reply" }) {
                                    Icon(Icons.Filled.Close, null, tint = p.muted, modifier = Modifier.size(16.dp))
                                }
                            }
                        }
                        if (canPost) {
                            val valid = VideoComment.isValidBody(draft)
                            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                                OutlinedTextField(
                                    value = draft, onValueChange = { draft = it },
                                    placeholder = { Text(if (replyTarget == null) "Add a comment…" else "Write a reply…") },
                                    maxLines = 4, enabled = !busy,
                                    modifier = Modifier.weight(1f).focusRequester(composerFocus).testTag("comment-text"),
                                )
                                Box(
                                    Modifier.size(44.dp).clip(CircleShape).background(p.accent).alpha(if (valid) 1f else 0.45f)
                                        .clickable(enabled = !busy && valid, onClick = ::submit)
                                        .semantics { contentDescription = "Post comment" }.testTag("post-comment"),
                                    contentAlignment = Alignment.Center,
                                ) { Icon(Icons.Filled.ArrowUpward, null, tint = p.onAccent) }
                            }
                            val count = VideoComment.scalarCount(draft)
                            if (count > 250) {
                                Text("$count/${VideoComment.MAX_LENGTH}", color = if (valid) p.muted else p.recording, fontSize = 11.sp,
                                    modifier = Modifier.testTag("comment-counter"))
                            }
                        } else {
                            StudioActionButton("Sign in to comment", icon = Icons.Outlined.ChatBubbleOutline, onClick = { showSignIn = true })
                        }
                    }
                }
            }

            action?.let { a ->
                AlertDialog(
                    onDismissRequest = { action = null },
                    title = { Text(a.title) },
                    text = {
                        Column {
                            if (a is CommentAction.Delete && a.comment.replyCount > 0) Text("This also removes the replies to this comment.")
                            if (a is CommentAction.Report) {
                                CommentReportReason.entries.forEach { reason ->
                                    TextButton(onClick = {
                                        action = null
                                        perform {
                                            feed.reportComment(a.comment.id, reason)
                                            notice = "Report sent. This comment is hidden for you."
                                            refreshThread(a.comment)
                                        }
                                    }, modifier = Modifier.fillMaxWidth()) { Text(reason.title) }
                                }
                            }
                        }
                    },
                    confirmButton = {
                        when (a) {
                            is CommentAction.Delete -> TextButton(onClick = {
                                action = null
                                perform { feed.deleteComment(a.comment.id); refreshThread(a.comment) }
                            }) { Text("Delete", color = p.recording) }
                            is CommentAction.Block -> TextButton(onClick = {
                                action = null
                                val uid = userId ?: return@TextButton
                                perform {
                                    feed.block(a.comment.userId, uid)
                                    onBlock(a.comment.userId)
                                    notice = "Blocked @${a.comment.username}."
                                    reload()
                                }
                            }) { Text("Block @${a.comment.username}", color = p.recording) }
                            is CommentAction.Report -> Unit
                        }
                    },
                    dismissButton = { TextButton(onClick = { action = null }) { Text("Cancel") } },
                )
            }
        }
    }
    if (showSignIn) SignInSheet(onDismiss = { showSignIn = false }, reason = "Sign in to join the conversation.")
}

@Composable
private fun Empty(title: String, detail: String) {
    val p = LocalStudioPalette.current
    Column(Modifier.fillMaxWidth().padding(vertical = 30.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Icon(Icons.Outlined.ChatBubbleOutline, null, tint = p.accent, modifier = Modifier.size(28.dp))
        Text(title, color = p.ink, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
        Text(detail, color = p.muted, fontSize = 15.sp, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
    }
}

@Composable
private fun CommentRow(
    comment: VideoComment,
    video: Video,
    viewer: UUID?,
    isOwner: Boolean,
    highlighted: Boolean,
    likeDisabled: Boolean,
    onReply: () -> Unit,
    onLike: () -> Unit,
    onAction: (CommentAction) -> Unit,
) {
    val p = LocalStudioPalette.current
    var menu by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(if (highlighted) p.accent.copy(alpha = 0.10f) else Color.Transparent).padding(4.dp),
        verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.size(32.dp).clip(CircleShape).background(p.surface), contentAlignment = Alignment.Center) {
            Text(comment.username.take(1).uppercase(), color = p.ink, fontWeight = FontWeight.Bold, fontSize = 12.sp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("@${comment.username}", color = p.ink, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                if (comment.userId == video.userId) {
                    Spacer(Modifier.width(6.dp)); Text("Creator", color = p.accent, fontWeight = FontWeight.SemiBold, fontSize = 11.sp)
                }
                Spacer(Modifier.weight(1f))
                Text(relativeTime(comment.createdAtInstant), color = p.muted, fontSize = 11.sp)
            }
            Text(comment.body, color = p.ink, fontSize = 15.sp)
            Text("Reply", color = p.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable(onClick = onReply).padding(vertical = 4.dp))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            comment.likeCount?.let { count ->
                val liked = comment.likedByMe == true
                Column(
                    Modifier.heightIn(min = 44.dp).width(44.dp).clickable(enabled = !likeDisabled, onClick = onLike)
                        .semantics(mergeDescendants = true) {
                            contentDescription = (if (liked) "Unlike comment by @" else "Like comment by @") + comment.username
                        }.testTag("comment-like-${comment.id.toString().lowercase()}"),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
                ) {
                    Icon(if (liked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder, null,
                        tint = if (liked) p.recording else p.muted, modifier = Modifier.size(18.dp))
                    Text(compactCount(count), color = if (liked) p.recording else p.muted, fontSize = 11.sp)
                }
            }
            Box {
                IconButton(onClick = { menu = true }, modifier = Modifier.semantics { contentDescription = "Options for comment by @${comment.username}" }) {
                    Icon(Icons.Filled.MoreHoriz, null, tint = p.muted)
                }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    if (comment.userId == viewer || isOwner) {
                        DropdownMenuItem(text = { Text("Delete comment", color = p.recording) }, onClick = { menu = false; onAction(CommentAction.Delete(comment)) })
                    }
                    if (comment.userId != viewer) {
                        DropdownMenuItem(text = { Text("Report comment") }, onClick = { menu = false; onAction(CommentAction.Report(comment)) })
                        DropdownMenuItem(text = { Text("Block @${comment.username}", color = p.recording) }, onClick = { menu = false; onAction(CommentAction.Block(comment)) })
                    }
                }
            }
        }
    }
}
