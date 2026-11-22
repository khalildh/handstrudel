#!/usr/bin/env python3
# Regenerates the engine catalogs (progressions, instruments, drum loops, camera
# filters, hand themes) from the iOS Swift sources:
#   python3 android/tools/gen_engine_catalogs.py ios/HandStrudel/HandStrudel android/app/src/main/java/com/handstrudel/models
import re, sys, os, json
IOS = sys.argv[1]; OUT = sys.argv[2]
M = os.path.join(IOS, 'Models')
def read(p): return open(os.path.join(M, p), encoding='utf-8').read()
def camel_to_const(s): return re.sub(r'(?<!^)(?=[A-Z])', '_', s).upper()
def kstr(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$') + '"'

# ---------------- Progressions ----------------
src = read('ChordProgression.swift')
cats = re.search(r'case (essentials[^\n]+\n[^\n]+)', src).group(1)
cats = [c.strip() for c in cats.replace('\n', ',').split(',') if c.strip()]
disp = dict(re.findall(r'case \.(\w+):\s+return "([^"]+)"', src[src.index('var displayName'):src.index('var emoji')]))
emo = dict(re.findall(r'case \.(\w+):\s+return "([^"]+)"', src[src.index('var emoji'):src.index('struct ChordProgression')]))
progs = re.findall(r'\.init\(id: "([^"]+)", name: "([^"]+)", emoji: "([^"]+)", degrees: \[([^\]]*)\], category: \.(\w+)\)', src)
lines = ['package com.handstrudel.models', '', '// GENERATED from ios/HandStrudel/HandStrudel/Models/ChordProgression.swift.', '// Do not edit by hand; see docs in ChordProgressions.kt.', '',
         '/** iOS `ProgressionCategory`, in the same order. */',
         'enum class ProgressionCategory(val raw: String, val displayName: String, val emoji: String) {']
lines += [f'    {camel_to_const(c)}({kstr(c)}, {kstr(disp[c])}, {kstr(emo[c])}),' for c in cats]
lines += ['}', '', '/** All built-in progressions (iOS `CHORD_PROGRESSIONS`), in iOS order. */', 'val CHORD_PROGRESSIONS: List<ChordProgression> = listOf(']
for i, n, e, d, c in progs:
    lines.append(f'    ChordProgression({kstr(i)}, {kstr(n)}, {kstr(e)}, listOf({d}), ProgressionCategory.{camel_to_const(c)}),')
lines += [')', '']
open(os.path.join(OUT, 'ChordProgressionCatalog.kt'), 'w').write('\n'.join(lines))
print('progressions', len(progs), 'categories', len(cats))

# ---------------- SoundFont instruments ----------------
src = read('SoundFontInstrument.swift')
gcats = re.search(r'case (piano[^\n]+\n[^\n]+)', src).group(1)
gcats = [c.strip() for c in gcats.replace('\n', ',').split(',') if c.strip()]
disp = dict(re.findall(r'case \.(\w+):\s+return "([^"]+)"', src[src.index('var displayName'):src.index('var emoji')]))
emo = dict(re.findall(r'case \.(\w+):\s+return "([^"]+)"', src[src.index('var emoji'):src.index('struct SoundFontInstrument')]))
free = re.findall(r'"(\w+)",', src[src.index('FREE_SOUNDFONT_INSTRUMENT_IDS'):src.index('let SOUNDFONT_INSTRUMENTS')])
insts = re.findall(r'SoundFontInstrument\(id: "([^"]+)",\s*name: "([^"]+)",\s*emoji: "([^"]+)", program: (\d+),\s*category: \.(\w+)\)', src)
lines = ['package com.handstrudel.models', '', '// GENERATED from ios/HandStrudel/HandStrudel/Models/SoundFontInstrument.swift.', '',
         '/** iOS `GMCategory`: the 16 General MIDI families, 8 programs each. */',
         'enum class GMCategory(val raw: String, val displayName: String, val emoji: String) {']
lines += [f'    {camel_to_const(c)}({kstr(c)}, {kstr(disp[c])}, {kstr(emo[c])}),' for c in gcats]
lines += ['}', '', '/** iOS `FREE_SOUNDFONT_INSTRUMENT_IDS`. */', 'val FREE_SOUNDFONT_INSTRUMENT_IDS: Set<String> = setOf(' + ', '.join(kstr(f) for f in free) + ')', '',
          '/** All 128 General MIDI programs, in order (iOS `SOUNDFONT_INSTRUMENTS`). */', 'val SOUNDFONT_INSTRUMENTS: List<SoundFontInstrument> = listOf(']
for i, n, e, p, c in insts:
    lines.append(f'    SoundFontInstrument({kstr(i)}, {kstr(n)}, {kstr(e)}, {p}, GMCategory.{camel_to_const(c)}),')
lines += [')', '']
open(os.path.join(OUT, 'SoundFontInstrumentCatalog.kt'), 'w').write('\n'.join(lines))
print('instruments', len(insts), 'free', len(free))

# ---------------- Drum loops ----------------
src = read('ParamDefs.swift')
vars_ = dict(re.findall(r'let (_\w+) = "((?:[^"\\]|\\.)*)"', src))
def expand(s):
    for _ in range(4):
        s = re.sub(r'\\\((_\w+)\)', lambda m: vars_[m.group(1)], s)
    return s.replace('\\"', '"')
for k in vars_: vars_[k] = expand(vars_[k])
loops = re.findall(r'DrumLoop\(id: "([^"]+)", name: "([^"]+)", emoji: "([^"]+)",\s*code: "((?:[^"\\]|\\.)*)",\s*isPremium: (true|false), packId: (nil|"[^"]+")\)', src)
lines = ['package com.handstrudel.models', '', '// GENERATED from ios/HandStrudel/HandStrudel/Models/ParamDefs.swift (DRUM_LOOPS).', '',
         '/** iOS `DrumLoop`: a Strudel drum pattern for the Drums 1 / Drums 2 tracks. */',
         'data class DrumLoop(val id: String, val name: String, val emoji: String, val code: String, val isPremium: Boolean, val packId: String?)', '',
         'val DRUM_LOOPS: List<DrumLoop> = listOf(']
for i, n, e, code, prem, pack in loops:
    pk = 'null' if pack == 'nil' else pack
    lines.append(f'    DrumLoop({kstr(i)}, {kstr(n)}, {kstr(e)}, {kstr(expand(code))}, {prem}, {pk}),')
lines += [')', '', 'fun drumLoop(id: String): DrumLoop = DRUM_LOOPS.firstOrNull { it.id == id } ?: DRUM_LOOPS[0]', '']
open(os.path.join(OUT, 'DrumLoops.kt'), 'w').write('\n'.join(lines))
print('drum loops', len(loops))

# ---------------- Camera filters ----------------
src = read('CameraFilter.swift')
def color(s):
    if s == 'nil': return 'null'
    m = re.match(r'Color\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)\)', s)
    if m: return f'FilterColor({float(m.group(1))}, {float(m.group(2))}, {float(m.group(3))})'
    m = re.match(r'Color\(white: ([\d.]+)\)', s)
    if m: return f'FilterColor({float(m.group(1))}, {float(m.group(1))}, {float(m.group(1))})'
    raise Exception(s)
fil = re.findall(r'CameraFilter\(id: "([^"]+)", name: "([^"]+)", emoji: "([^"]+)",\s*isPremium: (true|false), packId: (nil|"[^"]+"),\s*saturation: ([-\d.]+), contrast: ([-\d.]+), brightness: ([-\d.]+), hueRotation: ([-\d.]+),\s*overlayColor: (nil|Color\([^)]*\)), overlayOpacity: ([-\d.]+), blendMode: \.(\w+)\)', src)
lines = ['package com.handstrudel.models', '', '// GENERATED from ios/HandStrudel/HandStrudel/Models/CameraFilter.swift (data only; drawing is studio-ui).', '',
         'data class FilterColor(val red: Double, val green: Double, val blue: Double)', '',
         '/** SwiftUI `BlendMode` cases used by the filters. */', 'enum class FilterBlendMode { NORMAL, MULTIPLY, SCREEN, OVERLAY, SOFT_LIGHT, HARD_LIGHT, COLOR, COLOR_DODGE, COLOR_BURN, DIFFERENCE, LUMINOSITY, PLUS_LIGHTER, HUE, SATURATION, LIGHTEN, DARKEN, EXCLUSION }', '',
         '/** iOS `CameraFilter`: saturation/contrast/brightness/hue-rotation plus an optional colour overlay. */',
         'data class CameraFilter(', '    val id: String, val name: String, val emoji: String, val isPremium: Boolean, val packId: String?,',
         '    val saturation: Double, val contrast: Double, val brightness: Double, val hueRotation: Double,',
         '    val overlayColor: FilterColor?, val overlayOpacity: Double, val blendMode: FilterBlendMode,', ')', '',
         'val CAMERA_FILTERS: List<CameraFilter> = listOf(']
for (i, n, e, prem, pack, sat, con, bri, hue, oc, oo, bm) in fil:
    pk = 'null' if pack == 'nil' else pack
    lines.append(f'    CameraFilter({kstr(i)}, {kstr(n)}, {kstr(e)}, {prem}, {pk}, {float(sat)}, {float(con)}, {float(bri)}, {float(hue)}, {color(oc)}, {float(oo)}, FilterBlendMode.{camel_to_const(bm)}),')
lines += [')', '', 'fun cameraFilter(id: String): CameraFilter = CAMERA_FILTERS.firstOrNull { it.id == id } ?: CAMERA_FILTERS[0]', '']
open(os.path.join(OUT, 'CameraFilters.kt'), 'w').write('\n'.join(lines))
print('filters', len(fil), 'decl', src.count('CameraFilter(id:'))

# ---------------- Hand themes ----------------
src = read('HandTheme.swift')
def uicolor(s):
    s = s.strip()
    if s == 'UIColor.white': return 'FilterColor(1.0, 1.0, 1.0)'
    m = re.match(r'UIColor\(white: ([\d.]+), alpha: 1\)', s)
    if m: return f'FilterColor({float(m.group(1))}, {float(m.group(1))}, {float(m.group(1))})'
    m = re.match(r'UIColor\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+), alpha: 1\)', s)
    return f'FilterColor({float(m.group(1))}, {float(m.group(2))}, {float(m.group(3))})'
th = re.findall(r'HandTheme\(id: "([^"]+)", name: "([^"]+)", emoji: "([^"]+)",\s*leftColor: ([^\n]+),\s*rightColor: ([^\n]+),\s*glowIntensity: ([\d.]+), trailLength: ([\d.]+),\s*isPremium: (true|false), packId: (nil|"[^"]+")\)', src)
lines = ['package com.handstrudel.models', '', '// GENERATED from ios/HandStrudel/HandStrudel/Models/HandTheme.swift (data only; drawing is studio-ui).', '',
         'data class HandTheme(', '    val id: String, val name: String, val emoji: String, val leftColor: FilterColor, val rightColor: FilterColor,',
         '    val glowIntensity: Double, val trailLength: Double, val isPremium: Boolean, val packId: String?,', ')', '', 'val HAND_THEMES: List<HandTheme> = listOf(']
for (i, n, e, l, r, g, t, prem, pack) in th:
    pk = 'null' if pack == 'nil' else pack
    lines.append(f'    HandTheme({kstr(i)}, {kstr(n)}, {kstr(e)}, {uicolor(l.rstrip(","))}, {uicolor(r.rstrip(","))}, {float(g)}, {float(t)}, {prem}, {pk}),')
lines += [')', '', 'fun handTheme(id: String): HandTheme = HAND_THEMES.firstOrNull { it.id == id } ?: HAND_THEMES[0]', '']
open(os.path.join(OUT, 'HandThemes.kt'), 'w').write('\n'.join(lines))
print('themes', len(th))
