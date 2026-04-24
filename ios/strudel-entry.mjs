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

        // Load drum samples from Strudel CDN
        log('loading drum samples...');
        try {
            await _evaluate(`samples('github:tidalcycles/Dirt-Samples/master')`);
            log('drum samples loaded');
        } catch (e) {
            log('drum sample load error (non-fatal): ' + e);
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
