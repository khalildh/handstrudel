// Entry point for bundling all Strudel packages into a single file
import { repl, evalScope, reify, getTime } from '@strudel/core';
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

window.strudelStop = function() { if (_stop) _stop(); };

// Instant one-shot drum hit via Web Audio (bypasses Strudel scheduler for zero latency)
window.playHit = function(type) {
    if (!_audioCtx) return;
    const now = _audioCtx.currentTime;
    const gain = _audioCtx.createGain();
    gain.connect(_audioCtx.destination);

    switch(type) {
        case 'kick': {
            const osc = _audioCtx.createOscillator();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(150, now);
            osc.frequency.exponentialRampToValueAtTime(30, now + 0.15);
            gain.gain.setValueAtTime(1.2, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
            osc.connect(gain);
            osc.start(now);
            osc.stop(now + 0.3);
            break;
        }
        case 'snare': {
            // Noise burst
            const bufSize = _audioCtx.sampleRate * 0.12;
            const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = _audioCtx.createBufferSource();
            noise.buffer = buf;
            const hpf = _audioCtx.createBiquadFilter();
            hpf.type = 'highpass';
            hpf.frequency.value = 1000;
            const lpf = _audioCtx.createBiquadFilter();
            lpf.type = 'lowpass';
            lpf.frequency.value = 6000;
            gain.gain.setValueAtTime(0.8, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.12);
            noise.connect(hpf);
            hpf.connect(lpf);
            lpf.connect(gain);
            noise.start(now);
            noise.stop(now + 0.12);
            // Body tone
            const osc = _audioCtx.createOscillator();
            const g2 = _audioCtx.createGain();
            g2.connect(_audioCtx.destination);
            osc.type = 'triangle';
            osc.frequency.value = 160;
            g2.gain.setValueAtTime(0.5, now);
            g2.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
            osc.connect(g2);
            osc.start(now);
            osc.stop(now + 0.08);
            break;
        }
        case 'hihat': {
            const bufSize = _audioCtx.sampleRate * 0.03;
            const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = _audioCtx.createBufferSource();
            noise.buffer = buf;
            const hpf = _audioCtx.createBiquadFilter();
            hpf.type = 'highpass';
            hpf.frequency.value = 8000;
            gain.gain.setValueAtTime(0.4, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.03);
            noise.connect(hpf);
            hpf.connect(gain);
            noise.start(now);
            noise.stop(now + 0.03);
            break;
        }
        case 'crash': {
            const bufSize = _audioCtx.sampleRate * 0.2;
            const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = _audioCtx.createBufferSource();
            noise.buffer = buf;
            const hpf = _audioCtx.createBiquadFilter();
            hpf.type = 'highpass';
            hpf.frequency.value = 5000;
            gain.gain.setValueAtTime(0.5, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);
            noise.connect(hpf);
            hpf.connect(gain);
            noise.start(now);
            noise.stop(now + 0.2);
            break;
        }
        case 'ride': {
            const bufSize = _audioCtx.sampleRate * 0.15;
            const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = _audioCtx.createBufferSource();
            noise.buffer = buf;
            const bpf = _audioCtx.createBiquadFilter();
            bpf.type = 'bandpass';
            bpf.frequency.value = 6000;
            bpf.Q.value = 2;
            gain.gain.setValueAtTime(0.35, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
            noise.connect(bpf);
            bpf.connect(gain);
            noise.start(now);
            noise.stop(now + 0.15);
            break;
        }
        case 'tom': {
            const osc = _audioCtx.createOscillator();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(100, now);
            osc.frequency.exponentialRampToValueAtTime(50, now + 0.15);
            gain.gain.setValueAtTime(0.9, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);
            osc.connect(gain);
            osc.start(now);
            osc.stop(now + 0.2);
            break;
        }
    }
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
