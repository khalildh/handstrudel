package com.handstrudel.ui.social.feed

import android.os.Build
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp

/**
 * What the feed's More menu blurs (iOS presents the rail `Menu` on a dark system material).
 * The menu is a popup window, so it can't blur what is behind it directly: the feed records
 * its content into [layer] while a menu is open ([feedBackdropSource]) and the menu draws
 * that recording, offset to its own position and blurred with a `RenderEffect`
 * ([feedMenuMaterial]). Needs API 31; older devices keep the translucent card.
 */
@Stable
class FeedBackdrop internal constructor(internal val layer: GraphicsLayer) {
    internal var originOnScreen by mutableStateOf(Offset.Zero)
    internal var capturing by mutableStateOf(false)

    companion object {
        /** `RenderEffect` (and so a real blur) exists from API 31. */
        val isSupported: Boolean get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    }
}

@Composable
fun rememberFeedBackdrop(): FeedBackdrop {
    val layer = rememberGraphicsLayer()
    return remember(layer) { FeedBackdrop(layer) }
}

/**
 * Records this node's content into [backdrop] while a menu shows it; otherwise draws as usual.
 * [view] is this window's view (`LocalView.current`), to place the recording on screen.
 */
fun Modifier.feedBackdropSource(backdrop: FeedBackdrop, view: View): Modifier {
    if (!FeedBackdrop.isSupported) return this
    return this
        .onGloballyPositioned { backdrop.originOnScreen = it.screenPosition(view) }
        .drawWithContent {
            if (backdrop.capturing) {
                backdrop.layer.record { this@drawWithContent.drawContent() }
                drawLayer(backdrop.layer)
            } else {
                drawContent()
            }
        }
}

/** iOS dark menu material: the feed under the card, blurred, under a dark tint. */
internal val FeedMenuTint = Color(0xFF1C1C1E).copy(alpha = 0.5f)
/** Below API 31: the translucent card the menu used before (no blur available). */
internal val FeedMenuFallback = Color(0xFF2A2A2A).copy(alpha = 0.78f)

/**
 * State for one open menu. Call [Attach] from inside the popup content (so the popup's own
 * view is known and the menu redraws every frame while the video plays under it), and put
 * [modifier] on the menu container.
 */
@Stable
internal class FeedMenuMaterial(private val backdrop: FeedBackdrop?, private val blurLayer: GraphicsLayer) {
    private var popupView by mutableStateOf<View?>(null)
    private var origin by mutableStateOf(Offset.Zero)
    private var frame by mutableLongStateOf(0L)

    val active: Boolean get() = backdrop != null && FeedBackdrop.isSupported

    @Composable
    fun Attach() {
        if (!active) return
        val view = LocalView.current
        DisposableEffect(view) {
            popupView = view
            backdrop!!.capturing = true
            onDispose { backdrop.capturing = false }
        }
        // The video keeps playing under the card; redraw the blur with it.
        LaunchedEffect(Unit) { while (true) withFrameNanos { frame = it } }
    }

    val modifier: Modifier
        get() = if (!active) Modifier else Modifier
            .onGloballyPositioned { origin = it.screenPosition(popupView) }
            .drawBehind {
                frame // re-read each frame
                val source = backdrop!!
                if (source.capturing) {
                    val radius = 30.dp.toPx()
                    blurLayer.renderEffect = BlurEffect(radius, radius, TileMode.Clamp)
                    blurLayer.record {
                        val d = source.originOnScreen - origin
                        translate(d.x, d.y) { drawLayer(source.layer) }
                    }
                    drawLayer(blurLayer)
                }
                drawRect(FeedMenuTint)
            }
}

@Composable
internal fun rememberFeedMenuMaterial(backdrop: FeedBackdrop?): FeedMenuMaterial {
    val blurLayer = rememberGraphicsLayer()
    return remember(backdrop, blurLayer) { FeedMenuMaterial(backdrop, blurLayer) }
}

/** Top-left of this node on screen; [view] is the window's view when known (popups have their own). */
private fun LayoutCoordinates.screenPosition(view: View?): Offset {
    val inWindow = positionInWindow()
    view ?: return inWindow
    val onScreen = IntArray(2).also(view::getLocationOnScreen)
    val inViewWindow = IntArray(2).also(view::getLocationInWindow)
    return inWindow + Offset((onScreen[0] - inViewWindow[0]).toFloat(), (onScreen[1] - inViewWindow[1]).toFloat())
}
