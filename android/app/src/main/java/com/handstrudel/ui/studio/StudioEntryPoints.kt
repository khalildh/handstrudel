package com.handstrudel.ui.studio

import androidx.compose.runtime.Composable
import com.handstrudel.ui.studio.home.MusicHome as MusicHomeScreen
import com.handstrudel.ui.studio.stage.Stage as StageScreen

/**
 * Music tab entry points. Owner: studio-ui (WS3). Shell shows [MusicHome] on
 * the Music tab when idle and [Stage] full-screen while `engine.isRunning`.
 * Both read services from `LocalAppServices` / `LocalAppNavigator`.
 */
object StudioEntryPoints {

    /** iOS `StartOverlayView`. */
    @Composable
    fun MusicHome() = MusicHomeScreen()

    /** The full performance view (iOS `ContentView.performanceView`). */
    @Composable
    fun Stage() = StageScreen()
}
