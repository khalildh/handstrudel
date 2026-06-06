import Foundation

/// One playable mode (melodic, grid, drum, chord+melody, learn).
///
/// EngineController.tick() runs the active controller once per display-link
/// frame. Each controller reads shared engine state and services through the
/// passed-in `engine` and owns whatever scratch state is private to its mode,
/// which keeps the giant per-mode `tick*` methods out of EngineController and
/// makes each mode independently testable.
@MainActor
protocol ModeController {
    func tick(_ engine: EngineController)
}
