package com.handstrudel.engine

/**
 * Phase 0 adapter kept only so studio-ui's `Stage` cast
 * (`(engine as? LegacyStudioEngine)?.controller`) still finds the legacy Split
 * overlay API. Every [StudioEngine] member is the real engine
 * ([EngineController.engine]). TODO(studio-ui): drop the cast; then engine
 * deletes this class and [EngineController].
 */
class LegacyStudioEngine(val controller: EngineController) : StudioEngine by controller.engine
