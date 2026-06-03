// Entry point for bundling all Strudel packages into a single file
import { repl, evalScope, reify, getTime } from '@strudel/core';
import {
    webaudioOutput,
    initAudio,
    getAudioContext,
    registerSynthSounds,
} from '@strudel/webaudio';
import * as strudelCore from '@strudel/core';
import * as strudelMini from '@strudel/mini';
import * as strudelTonal from '@strudel/tonal';
import * as strudelWebaudio from '@strudel/webaudio';

window.__hp = {};

let _evaluate = null;
let _stop = null;
let _audioCtx = null;
let _ready = false;

function log(msg) {
    console.log('[strudel]', msg);
    window.webkit?.messageHandlers?.strudelBridge?.postMessage({ log: msg });
}

window.initStrudel = async function() {
    if (_ready) return 'ok';
    try {
        log('registering synth sounds...');
        registerSynthSounds();

        log('calling evalScope...');
        await evalScope(strudelCore, strudelMini, strudelTonal, strudelWebaudio);

        log('calling initAudio...');
        await initAudio();
        _audioCtx = getAudioContext();
        log('audio context ready');

        const r = repl({
            defaultOutput: webaudioOutput,
            getTime: () => _audioCtx?.currentTime ?? 0,
            onSchedulerError: e => log('sched error: ' + e),
            onEvalError: e => log('eval error: ' + e),
        });

        _evaluate = r.evaluate;
        _stop = r.stop;
        log('repl created');

        // Beat reporting
        if (_audioCtx) {
            let lastBeat = -1;
            const checkBeat = () => {
                try {
                    const cpm = (window.__hp._cpm || 30);
                    const beat = Math.floor((_audioCtx.currentTime * cpm / 60) * 4) % 4;
                    if (beat !== lastBeat) {
                        lastBeat = beat;
                        window.webkit?.messageHandlers?.strudelBridge?.postMessage({ beat });
                    }
                } catch {}
                requestAnimationFrame(checkBeat);
            };
            checkBeat();
        }

        // Initialize Hydra (loaded via classic script tag before this module)
        if (typeof Hydra !== 'undefined') {
            try {
                const canvas = document.getElementById('hydra-canvas');
                canvas.width = window.innerWidth || 390;
                canvas.height = window.innerHeight || 844;
                new Hydra({ canvas, detectAudio: false, makeGlobal: true, autoLoop: true });
                window.H = (pat) => () => reify(pat).queryArc(getTime(), getTime())[0]?.value ?? 0;
                log('hydra initialized');
            } catch (e) {
                log('hydra init failed: ' + e);
            }
        } else {
            log('hydra not available (script not loaded)');
        }

        // Load drum samples via Strudel's evaluate (runs in sandboxed scope where samples() lives)
        log('loading drum samples...');
        try {
            await _evaluate(`samples('github:tidalcycles/Dirt-Samples/master')`);
            log('drum samples loaded via evaluate');
        } catch (e) {
            log('evaluate samples error: ' + e);
            // Fallback: try globalThis
            try {
                if (typeof globalThis.samples === 'function') {
                    await globalThis.samples('github:tidalcycles/Dirt-Samples/master');
                    log('drum samples loaded via globalThis');
                }
            } catch (e2) {
                log('globalThis samples also failed: ' + e2);
            }
        }

        // Load GM-style pitched sample instrument manifests (just JSON,
        // ~10KB total). Audio files are fetched lazily on first use.
        log('loading sample-instrument manifests...');
        try {
            await loadBundledInstruments();
            log('sample instruments ready: ' + Object.keys(window._sampleInstruments || {}).join(','));
        } catch (e) {
            log('sample manifest load error: ' + e);
        }

        _ready = true;
        log('strudel ready');
        return 'ok';
    } catch (e) {
        log('initStrudel FAILED: ' + e);
        throw e;
    }
};

window.strudelEval = async function(code) {
    if (_evaluate) {
        try { await _evaluate(code); }
        catch (e) { log('eval error: ' + e); }
    }
};

window.hydraEval = function(code) {
    try { new Function(code)(); }
    catch (e) { log('hydra eval: ' + e); }
};

window.strudelStop = function() {
    if (_stop) _stop();
    // Kill all active Web Audio voices
    for (const hand of Object.keys(window._voices || {})) {
        window.noteOff(hand);
    }
};

// Drum hit parameters (set from Swift via XY pad)
window._drumIntensity = 0.5;  // 0=soft, 1=loud
window._drumComplexity = 0.5; // 0=simple/dry, 1=complex/wet

// Instant one-shot drum hit via Web Audio
// intensity affects volume + decay length
// complexity affects pitch variation + reverb-like tail
window.playHit = function(type) {
    if (!_audioCtx) return;
    const now = _audioCtx.currentTime;
    const vol = 0.3 + window._drumIntensity * 1.2; // 0.3-1.5
    const decay = 0.8 + window._drumComplexity * 1.5; // decay multiplier
    const pitchVar = 1 + (window._drumComplexity - 0.5) * 0.3; // slight pitch variation

    const gain = _audioCtx.createGain();

    // Add delay/reverb effect based on complexity
    if (window._drumComplexity > 0.3) {
        const delay = _audioCtx.createDelay();
        delay.delayTime.value = 0.08 + window._drumComplexity * 0.12;
        const fb = _audioCtx.createGain();
        fb.gain.value = window._drumComplexity * 0.4;
        const wetGain = _audioCtx.createGain();
        wetGain.gain.value = window._drumComplexity * 0.3;
        gain.connect(delay);
        delay.connect(fb);
        fb.connect(delay);
        delay.connect(wetGain);
        wetGain.connect(_audioCtx.destination);
    }
    gain.connect(_audioCtx.destination);

    switch(type) {
        case 'kick': {
            const osc = _audioCtx.createOscillator();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(150 * pitchVar, now);
            osc.frequency.exponentialRampToValueAtTime(30, now + 0.15 * decay);
            gain.gain.setValueAtTime(vol, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.3 * decay);
            osc.connect(gain);
            osc.start(now);
            osc.stop(now + 0.5 * decay);
            break;
        }
        case 'snare': {
            const dur = 0.12 * decay;
            const bufSize = _audioCtx.sampleRate * dur;
            const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = _audioCtx.createBufferSource();
            noise.buffer = buf;
            const hpf = _audioCtx.createBiquadFilter();
            hpf.type = 'highpass';
            hpf.frequency.value = 800 + (1 - window._drumComplexity) * 400;
            const lpf = _audioCtx.createBiquadFilter();
            lpf.type = 'lowpass';
            lpf.frequency.value = 4000 + window._drumIntensity * 4000;
            gain.gain.setValueAtTime(vol * 0.7, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + dur);
            noise.connect(hpf);
            hpf.connect(lpf);
            lpf.connect(gain);
            noise.start(now);
            noise.stop(now + dur + 0.1);
            const osc = _audioCtx.createOscillator();
            const g2 = _audioCtx.createGain();
            g2.connect(_audioCtx.destination);
            osc.type = 'triangle';
            osc.frequency.value = 160 * pitchVar;
            g2.gain.setValueAtTime(vol * 0.4, now);
            g2.gain.exponentialRampToValueAtTime(0.001, now + 0.08 * decay);
            osc.connect(g2);
            osc.start(now);
            osc.stop(now + 0.15 * decay);
            break;
        }
        case 'hihat': {
            const dur = (0.02 + window._drumComplexity * 0.08) * decay;
            const bufSize = _audioCtx.sampleRate * dur;
            const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = _audioCtx.createBufferSource();
            noise.buffer = buf;
            const hpf = _audioCtx.createBiquadFilter();
            hpf.type = 'highpass';
            hpf.frequency.value = 6000 + (1 - window._drumComplexity) * 4000;
            gain.gain.setValueAtTime(vol * 0.35, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + dur);
            noise.connect(hpf);
            hpf.connect(gain);
            noise.start(now);
            noise.stop(now + dur + 0.1);
            break;
        }
        case 'crash': {
            const dur = (0.15 + window._drumComplexity * 0.3) * decay;
            const bufSize = _audioCtx.sampleRate * dur;
            const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = _audioCtx.createBufferSource();
            noise.buffer = buf;
            const hpf = _audioCtx.createBiquadFilter();
            hpf.type = 'highpass';
            hpf.frequency.value = 4000;
            gain.gain.setValueAtTime(vol * 0.5, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + dur);
            noise.connect(hpf);
            hpf.connect(gain);
            noise.start(now);
            noise.stop(now + dur + 0.1);
            break;
        }
        case 'ride': {
            const dur = (0.1 + window._drumComplexity * 0.15) * decay;
            const bufSize = _audioCtx.sampleRate * dur;
            const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = _audioCtx.createBufferSource();
            noise.buffer = buf;
            const bpf = _audioCtx.createBiquadFilter();
            bpf.type = 'bandpass';
            bpf.frequency.value = 5000 + window._drumComplexity * 2000;
            bpf.Q.value = 1 + window._drumComplexity * 3;
            gain.gain.setValueAtTime(vol * 0.35, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + dur);
            noise.connect(bpf);
            bpf.connect(gain);
            noise.start(now);
            noise.stop(now + dur + 0.1);
            break;
        }
        case 'tom': {
            const osc = _audioCtx.createOscillator();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(100 * pitchVar, now);
            osc.frequency.exponentialRampToValueAtTime(50, now + 0.15 * decay);
            gain.gain.setValueAtTime(vol * 0.9, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2 * decay);
            osc.connect(gain);
            osc.start(now);
            osc.stop(now + 0.4 * decay);
            break;
        }
    }
};

// ---------------------------------------------------------------------------
// Sample-based pitched instruments (piano, organ, strings, etc.)
//
// Each "instrument" maps a string id (used as the `waveform` arg from Swift)
// to a sample set: { notes: { midi: url } }. We pick the closest sampled
// note to the requested pitch and use `playbackRate` to fill in the gap.
// Audio buffers are fetched lazily on first use, then cached forever.
// ---------------------------------------------------------------------------

window._sampleInstruments = {};

// Note-name -> MIDI helper. Accepts "C4", "Ds4", "F#4", "Eb3", "A#1", etc.
const _NOTE_SEMI = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
function _noteNameToMidi(name) {
    const m = /^([A-Ga-g])([#sb]?)(-?\d+)$/.exec(name);
    if (!m) return null;
    let semi = _NOTE_SEMI[m[1].toUpperCase()];
    if (semi == null) return null;
    if (m[2] === '#' || m[2] === 's') semi += 1;
    if (m[2] === 'b') semi -= 1;
    const octave = parseInt(m[3], 10);
    // MIDI standard: C4 = 60, C-1 = 0, so midi = (octave + 1) * 12 + semi
    return (octave + 1) * 12 + semi;
}

// Per-instrument: pick the sampled note closest to the requested midi.
function _findClosestSampledNote(inst, midi) {
    let best = null;
    let bestDist = Infinity;
    for (let i = 0; i < inst.midis.length; i++) {
        const d = Math.abs(inst.midis[i] - midi);
        if (d < bestDist) { bestDist = d; best = i; }
    }
    return best == null ? null : { midi: inst.midis[best], url: inst.urls[best] };
}

// Build a single instrument record from a sample-map entry of shape:
//   { _base: "...", "C4": "c4.mp3", "G4": ["g4a.mp3", "g4b.mp3"], ... }
// Base is optional and overrides the parent base.
function _buildInstrument(rawNotes, parentBase) {
    const base = rawNotes._base || parentBase || '';
    const midis = [];
    const urls = [];
    for (const [noteName, files] of Object.entries(rawNotes)) {
        if (noteName === '_base') continue;
        const midi = _noteNameToMidi(noteName);
        if (midi == null) continue;
        const file = Array.isArray(files) ? files[0] : files;
        midis.push(midi);
        // Some VCSL paths ship with literal spaces (e.g. "Concert Harp/..."),
        // others are already encoded. Encode the path portion conservatively
        // so % and / pass through unchanged.
        urls.push(base + encodeURI(file).replace(/%25/g, '%'));
    }
    if (!midis.length) return null;
    // Sort by midi so binary searches / scans are predictable.
    const order = midis.map((_, i) => i).sort((a, b) => midis[a] - midis[b]);
    return {
        midis: order.map(i => midis[i]),
        urls: order.map(i => urls[i]),
    };
}

// Bundled instrument manifest produced by ios/prepare-samples.py at build
// time. Lives alongside the HTML in the app's Resources/instrument-samples
// folder. We can't use a relative file:// URL because WebKit blocks fetch()
// for file scheme — instead Swift registers an `app-samples://` URL scheme
// handler that maps host+path back to the bundle path.
const BUNDLED_MANIFEST = 'app-samples://bundled-instruments.json';
const BUNDLED_AUDIO_BASE = 'app-samples://';


async function loadBundledInstruments() {
    let json;
    try {
        const res = await fetch(BUNDLED_MANIFEST);
        if (!res.ok) throw new Error('HTTP ' + res.status);
        json = await res.json();
    } catch (err) {
        log('bundled manifest fetch failed: ' + err);
        return;
    }
    const audioDir = (json._audio_dir || 'audio').replace(/\/$/, '');
    const baseDir = BUNDLED_AUDIO_BASE + audioDir + '/';
    for (const [instId, notes] of Object.entries(json.instruments || {})) {
        const midis = [];
        const urls = [];
        for (const [noteName, relPath] of Object.entries(notes)) {
            const midi = _noteNameToMidi(noteName);
            if (midi == null) continue;
            midis.push(midi);
            urls.push(baseDir + relPath);
        }
        if (!midis.length) continue;
        const order = midis.map((_, i) => i).sort((a, b) => midis[a] - midis[b]);
        window._sampleInstruments[instId] = {
            midis: order.map(i => midis[i]),
            urls: order.map(i => urls[i]),
        };
    }
    log('bundled instruments ready: ' + Object.keys(window._sampleInstruments).join(','));
}

// Buffer cache for bundled samples — key: url, value: AudioBuffer | Promise.
window._sampleBufferCache = {};

async function _fetchAndDecode(url) {
    log('  ↓ ' + url);
    let res;
    try { res = await fetch(url); }
    catch (e) { log('  ✗ fetch threw: ' + e + ' (' + url + ')'); throw e; }
    if (!res.ok) {
        log('  ✗ HTTP ' + res.status + ' for ' + url);
        throw new Error('HTTP ' + res.status + ' for ' + url);
    }
    const ab = await res.arrayBuffer();
    log('  • got ' + ab.byteLength + ' bytes for ' + url + ', decoding…');
    try {
        const buf = await _audioCtx.decodeAudioData(ab);
        log('  ✓ decoded ' + url + ' (' + buf.duration.toFixed(2) + 's)');
        return buf;
    } catch (e) {
        log('  ✗ decode failed for ' + url + ': ' + e);
        throw e;
    }
}

function _getSampleBuffer(inst, midi) {
    const choice = _findClosestSampledNote(inst, midi);
    if (!choice) return null;
    const cached = window._sampleBufferCache[choice.url];
    if (cached && cached.buffer) return { buffer: cached.buffer, sampledMidi: choice.midi };
    if (cached && cached.then) return null; // load in flight
    log('sample fetch start: ' + choice.url);
    const p = _fetchAndDecode(choice.url)
        .then(buffer => {
            log('sample fetch ok: ' + choice.url + ' (' + Math.round(buffer.duration * 1000) + 'ms)');
            window._sampleBufferCache[choice.url] = { buffer };
            return buffer;
        })
        .catch(e => { log('sample decode error ' + choice.url + ': ' + e); delete window._sampleBufferCache[choice.url]; });
    window._sampleBufferCache[choice.url] = p;
    return null;
}

function _isSampleInstrument(name) {
    return !!(name && window._sampleInstruments[name]);
}

// ---------------------------------------------------------------------------
// Sustained note system — noteOn starts, noteOff releases
// Each hand gets its own voice (left/right) so they don't interfere
// ---------------------------------------------------------------------------
window._voices = {};

function _startSampleVoice(hand, midi, instName, vel) {
    const inst = window._sampleInstruments[instName];
    if (!inst) return false;

    // Reserve the voice slot synchronously so noteOff during the (very brief)
    // async load knows to cancel us. The voice object is "armed" — when the
    // buffer arrives, we attach + start; if `cancelled` is set first, drop it.
    const slot = { hand, midi, instName, vel, kind: 'sample', armed: true, cancelled: false };
    window._voices[hand] = slot;

    const playWhenReady = (sampledChoice, buffer) => {
        if (slot.cancelled) return;
        const now = _audioCtx.currentTime;
        const v = vel || 0.6;
        const semitoneOffset = midi - sampledChoice.midi;
        const playbackRate = Math.pow(2, semitoneOffset / 12);

        const src = _audioCtx.createBufferSource();
        src.buffer = buffer;
        src.playbackRate.value = playbackRate;

        const gain = _audioCtx.createGain();
        gain.gain.setValueAtTime(0, now);
        gain.gain.linearRampToValueAtTime(v * 0.6, now + 0.01);

        const lpf = _audioCtx.createBiquadFilter();
        lpf.type = 'lowpass';
        lpf.frequency.value = 3000 + v * 3000;

        src.connect(lpf);
        lpf.connect(gain);
        gain.connect(_audioCtx.destination);
        src.start(now);

        // Promote the armed slot into a fully started voice. Preserve any
        // mutations noteSlide may have made to slot.midi.
        slot.armed = false;
        slot.src = src;
        slot.gain = gain;
        slot.lpf = lpf;
        slot.sampledMidi = sampledChoice.midi;
    };

    const choice = _findClosestSampledNote(inst, slot.midi);
    if (!choice) { delete window._voices[hand]; return false; }

    const cached = window._sampleBufferCache[choice.url];
    if (cached && cached.buffer) {
        // Hot path — buffer already decoded, play synchronously.
        playWhenReady(choice, cached.buffer);
    } else {
        // Cold path — load (or join existing load) then start when ready.
        const ensurePromise = (cached && cached.then)
            ? cached
            : (() => {
                log('sample fetch start: ' + choice.url);
                const p = _fetchAndDecode(choice.url)
                    .then(buf => {
                        log('sample fetch ok: ' + choice.url + ' (' + Math.round(buf.duration * 1000) + 'ms)');
                        window._sampleBufferCache[choice.url] = { buffer: buf };
                        return buf;
                    })
                    .catch(e => {
                        log('sample decode error ' + choice.url + ': ' + e);
                        delete window._sampleBufferCache[choice.url];
                        throw e;
                    });
                window._sampleBufferCache[choice.url] = p;
                return p;
            })();
        ensurePromise.then(buf => playWhenReady(choice, buf)).catch(() => {});
    }
    return true;
}

window.noteOn = function(hand, midi, waveform, vel) {
    if (!_audioCtx) return;
    // Stop any existing voice for this hand
    window.noteOff(hand);

    // Sample instrument path — fall through to oscillator if not a sample id.
    if (_isSampleInstrument(waveform)) {
        if (_startSampleVoice(hand, midi, waveform, vel)) return;
    }

    const now = _audioCtx.currentTime;
    const freq = 440 * Math.pow(2, (midi - 69) / 12);
    const v = vel || 0.6;

    const osc = _audioCtx.createOscillator();
    osc.type = waveform || 'sawtooth';
    osc.frequency.setValueAtTime(freq, now);

    const gain = _audioCtx.createGain();
    // Quick attack
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(v * 0.5, now + 0.01);

    const lpf = _audioCtx.createBiquadFilter();
    lpf.type = 'lowpass';
    lpf.frequency.value = 3000 + v * 3000;

    osc.connect(lpf);
    lpf.connect(gain);
    gain.connect(_audioCtx.destination);
    osc.start(now);

    window._voices[hand] = { osc, gain, midi, kind: 'osc' };
};

window.noteOff = function(hand) {
    const voice = window._voices[hand];
    if (!voice) return;
    // Armed sample voice still waiting for its buffer — just cancel.
    if (voice.kind === 'sample' && voice.armed) {
        voice.cancelled = true;
        delete window._voices[hand];
        return;
    }
    const now = _audioCtx.currentTime;
    voice.gain.gain.cancelScheduledValues(now);
    voice.gain.gain.setValueAtTime(voice.gain.gain.value, now);
    voice.gain.gain.exponentialRampToValueAtTime(0.001, now + 0.05);
    if (voice.kind === 'sample') {
        try { voice.src.stop(now + 0.06); } catch {}
    } else {
        try { voice.osc.stop(now + 0.06); } catch {}
    }
    delete window._voices[hand];
};

// Change pitch of a held note without retriggering (for sliding between lanes)
window.noteSlide = function(hand, midi) {
    const voice = window._voices[hand];
    if (!voice || voice.midi === midi) return;
    if (voice.kind === 'sample' && voice.armed) {
        // Buffer still loading — just remember the new target pitch; the
        // promote-to-started path uses voice.midi when wiring playbackRate.
        voice.midi = midi;
        return;
    }
    if (voice.kind === 'sample') {
        // Sample slide: adjust playbackRate relative to the originally chosen
        // sampled note. Crossing into a different sample zone would require
        // retriggering, which clicks — accept the slightly off-pitch playback
        // up to a few semitones and only retrigger if we drift far.
        const inst = window._sampleInstruments[voice.instName];
        if (!inst) return;
        const choice = _findClosestSampledNote(inst, midi);
        // If still within a few semitones of the currently-playing sample,
        // just adjust playbackRate. Otherwise retrigger cleanly.
        const currentSampled = voice.sampledMidi != null ? voice.sampledMidi : (choice ? choice.midi : midi);
        if (choice && Math.abs(choice.midi - currentSampled) <= 3) {
            const offset = midi - currentSampled;
            const now = _audioCtx.currentTime;
            voice.src.playbackRate.setValueAtTime(Math.pow(2, offset / 12), now);
            voice.midi = midi;
            voice.sampledMidi = currentSampled;
        } else {
            // Far away — retrigger with the new sample.
            const wf = voice.instName;
            window.noteOff(hand);
            window.noteOn(hand, midi, wf, 0.6);
        }
        return;
    }
    const now = _audioCtx.currentTime;
    const freq = 440 * Math.pow(2, (midi - 69) / 12);
    voice.osc.frequency.setValueAtTime(freq, now);
    voice.midi = midi;
};

// Legacy one-shot (kept for backward compat)
window.playNote = function(midi, waveform, vel, duration) {
    window.noteOn('oneshot', midi, waveform, vel);
    setTimeout(() => window.noteOff('oneshot'), (duration || 0.3) * 1000);
};

window.showHydra = function() {
    const c = document.getElementById('hydra-canvas');
    if (c) c.style.display = '';
};

window.hideHydra = function() {
    const c = document.getElementById('hydra-canvas');
    if (c) c.style.display = 'none';
    try { new Function('solid(0,0,0,0).out()')(); } catch {}
};

window.addEventListener('resize', () => {
    const c = document.getElementById('hydra-canvas');
    if (c) { c.width = window.innerWidth; c.height = window.innerHeight; }
});

window._moduleReady = true;
log('module ready');
window.webkit?.messageHandlers?.strudelBridge?.postMessage({ ready: true });
