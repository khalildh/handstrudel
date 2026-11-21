# Instrument goldens

Checks the web port of the instrument format (`src/lib/instruments/`) against
the real iOS code. It compiles `InstrumentSpec.swift` and `MusicTheory.swift`
unchanged (plus a one-line stub), runs the loader on every shared fixture and
on extra edge cases, and records the wheel rules for every key, built-in scale
and degree. `src/lib/instruments/spec.test.ts` asserts the TypeScript port
gives the same answers.

Regenerate after changing the Swift loader, the rules or `make-cases.mjs`:

```bash
node scripts/instrument-goldens/generate.mjs
```
