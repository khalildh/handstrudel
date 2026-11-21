package com.handstrudel.app

import android.app.Application
import com.handstrudel.ui.nav.DefaultAppNavigator
import kotlinx.coroutines.MainScope

/**
 * Process-wide composition root. Owner: shell. [services] and [navigator] are created
 * once per process, so the engine, tab and session state survive activity recreation
 * (fold/unfold, theme or density changes) the way iOS `@StateObject`s outlive view updates.
 */
class HandStrudelApplication : Application() {
    private val appScope = MainScope()

    val services: AppServices by lazy { AppServices.create(this) }
    val navigator: DefaultAppNavigator by lazy {
        DefaultAppNavigator(services, appScope, this).also { services.capture.attach(it) }
    }
}
