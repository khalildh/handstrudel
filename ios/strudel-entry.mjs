// Entry point for bundling all Strudel packages into a single file
import { repl, evalScope } from '@strudel/core';
import { webaudioOutput, initAudio, getAudioContext, registerSynthSounds } from '@strudel/webaudio';
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

// Sustained note system — noteOn starts, noteOff releases.
// A voice may contain multiple oscillators (supersaw stacks 3 detuned saws;
// FM uses a carrier + modulator). All share one gain + filter path so
// noteOff/noteSlide work uniformly.
window._voices = {};

window._pulseWave = null;
function getPulseWave() {
    if (!_audioCtx) return null;
    if (window._pulseWave) return window._pulseWave;
    const N = 64;
    const real = new Float32Array(N);
    const imag = new Float32Array(N);
    const duty = 0.25;
    for (let i = 1; i < N; i++) {
        imag[i] = (1 / i) * (1 - Math.cos(2 * Math.PI * i * duty));
    }
    window._pulseWave = _audioCtx.createPeriodicWave(real, imag, { disableNormalization: false });
    return window._pulseWave;
}

window.noteOn = function(hand, midi, waveform, vel) {
    if (!_audioCtx) return;
    window.noteOff(hand);

    const ctx = _audioCtx;
    const now = ctx.currentTime;
    const freq = 440 * Math.pow(2, (midi - 69) / 12);
    const v = vel || 0.6;
    const w = waveform || 'sawtooth';

    const gain = ctx.createGain();
    const lpf = ctx.createBiquadFilter();
    lpf.type = 'lowpass';
    lpf.frequency.value = 3000 + v * 3000;
    lpf.connect(gain);
    gain.connect(ctx.destination);

    const oscs = [];
    const auxNodes = [];
    let attack = 0.01;
    let peak = v * 0.5;
    gain.gain.setValueAtTime(0, now);

    if (w === 'supersaw') {
        for (const d of [-9, 0, 9]) {
            const o = ctx.createOscillator();
            o.type = 'sawtooth';
            o.frequency.setValueAtTime(freq, now);
            o.detune.setValueAtTime(d, now);
            o.connect(lpf);
            o.start(now);
            oscs.push(o);
        }
        peak = v * 0.35;
    } else if (w === 'pulse') {
        const o = ctx.createOscillator();
        const pw = getPulseWave();
        if (pw) o.setPeriodicWave(pw); else o.type = 'square';
        o.frequency.setValueAtTime(freq, now);
        o.connect(lpf);
        o.start(now);
        oscs.push(o);
    } else if (w === 'fm') {
        const carrier = ctx.createOscillator();
        carrier.type = 'sine';
        carrier.frequency.setValueAtTime(freq, now);
        const modulator = ctx.createOscillator();
        modulator.type = 'sine';
        modulator.frequency.setValueAtTime(freq * 1.5, now);
        const modGain = ctx.createGain();
        modGain.gain.setValueAtTime(freq * 1.2, now);
        modGain.gain.exponentialRampToValueAtTime(Math.max(0.001, freq * 0.05), now + 0.6);
        modulator.connect(modGain);
        modGain.connect(carrier.frequency);
        carrier.connect(lpf);
        modulator.start(now);
        carrier.start(now);
        oscs.push(carrier);
        auxNodes.push(modulator);
    } else if (w === 'pluck') {
        const o = ctx.createOscillator();
        o.type = 'triangle';
        o.frequency.setValueAtTime(freq, now);
        o.connect(lpf);
        o.start(now);
        oscs.push(o);
        attack = 0.003;
        peak = v * 0.7;
        lpf.frequency.cancelScheduledValues(now);
        lpf.frequency.setValueAtTime(5000 + v * 3000, now);
        lpf.frequency.exponentialRampToValueAtTime(800, now + 1.2);
        gain.gain.linearRampToValueAtTime(peak, now + attack);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 1.5);
    } else {
        const o = ctx.createOscillator();
        try { o.type = w; } catch (_) { o.type = 'sawtooth'; }
        o.frequency.setValueAtTime(freq, now);
        o.connect(lpf);
        o.start(now);
        oscs.push(o);
    }

    if (w !== 'pluck') {
        gain.gain.linearRampToValueAtTime(peak, now + attack);
    }

    window._voices[hand] = { oscs, auxNodes, gain, lpf, midi, waveform: w };
};

window.noteOff = function(hand) {
    const voice = window._voices[hand];
    if (!voice) return;
    const now = _audioCtx.currentTime;
    voice.gain.gain.cancelScheduledValues(now);
    voice.gain.gain.setValueAtTime(voice.gain.gain.value, now);
    voice.gain.gain.exponentialRampToValueAtTime(0.001, now + 0.05);
    const stopAt = now + 0.06;
    (voice.oscs || []).forEach(o => { try { o.stop(stopAt); } catch (_) {} });
    (voice.auxNodes || []).forEach(n => { try { n.stop(stopAt); } catch (_) {} });
    delete window._voices[hand];
};

window.noteSlide = function(hand, midi) {
    const voice = window._voices[hand];
    if (!voice || voice.midi === midi) return;
    const now = _audioCtx.currentTime;
    const freq = 440 * Math.pow(2, (midi - 69) / 12);
    if (voice.waveform === 'fm') {
        (voice.oscs || []).forEach(o => o.frequency.setValueAtTime(freq, now));
        (voice.auxNodes || []).forEach(n => {
            if (n.frequency) n.frequency.setValueAtTime(freq * 1.5, now);
        });
    } else {
        (voice.oscs || []).forEach(o => o.frequency.setValueAtTime(freq, now));
    }
    voice.midi = midi;
};

// Legacy one-shot (kept for backward compat)
window.playNote = function(midi, waveform, vel, duration) {
    window.noteOn('oneshot', midi, waveform, vel);
    setTimeout(() => window.noteOff('oneshot'), (duration || 0.3) * 1000);
};

window._moduleReady = true;
log('module ready');
window.webkit?.messageHandlers?.strudelBridge?.postMessage({ ready: true });
