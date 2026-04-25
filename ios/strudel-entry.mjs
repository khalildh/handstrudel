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

        // Hydra will be initialized lazily in showHydra() when canvas is full-screen
        log('hydra available: ' + (typeof Hydra !== 'undefined'));
        window._hydraInitialized = false;

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

window.showHydra = function(w, h) {
    const c = document.getElementById('hydra-canvas');
    if (!c) return;

    c.width = w || window.innerWidth || 390;
    c.height = h || window.innerHeight || 844;
    c.style.display = '';
    log('showHydra: canvas ' + c.width + 'x' + c.height);

    // Initialize Hydra on first show (WebGL context needs correct canvas size)
    if (!window._hydraInitialized && typeof Hydra !== 'undefined') {
        try {
            new Hydra({ canvas: c, detectAudio: false, makeGlobal: true, autoLoop: true });
            window.H = (pat) => () => reify(pat).queryArc(getTime(), getTime())[0]?.value ?? 0;
            window._hydraInitialized = true;
            log('hydra initialized at ' + c.width + 'x' + c.height);
        } catch (e) {
            log('hydra init failed: ' + e);
        }
    }

    // Kick-start with a default pattern
    try { new Function('osc(10,0.1,1.5).out()')(); } catch(e) { log('hydra kickstart error: ' + e); }
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
