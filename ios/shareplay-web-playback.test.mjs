import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const bundle = readFileSync(new URL('./HandStrudel/HandStrudel/Resources/strudel-bundle.js', import.meta.url), 'utf8');

function makePlayback(t) {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const sandbox = {
        console: { log() {} },
        document: { addEventListener() {} },
        addEventListener() {},
        performance,
        setTimeout,
        clearTimeout,
    };
    sandbox.window = sandbox;
    runInNewContext(bundle, sandbox);

    // Use the shipped one-shot scheduler with an in-memory voice table in place of Web Audio.
    sandbox.noteOff = id => delete sandbox._voices[id];
    sandbox.noteOn = (id, midi) => {
        sandbox.noteOff(id);
        sandbox._voices[id] = { midi };
    };

    return {
        play: (midi, duration) => sandbox.playNote(midi, 'triangle', 0.5, duration),
        pitches: () => Object.values(sandbox._voices).map(voice => voice.midi).sort((a, b) => a - b),
        advance: milliseconds => t.mock.timers.tick(milliseconds),
        stop: () => sandbox.strudelStop(),
    };
}

test('a SharePlay one-shot chord keeps all pitches active for the duration', t => {
    const audio = makePlayback(t);
    // The Swift SharePlay fallback calls playNote once per chord pitch.
    for (const midi of [60, 64, 67]) audio.play(midi, 0.25);
    audio.advance(249);
    assert.deepEqual(audio.pitches(), [60, 64, 67]);
    audio.advance(1);
    assert.deepEqual(audio.pitches(), []);
});

test('an earlier SharePlay note releases only its own pitch', t => {
    const audio = makePlayback(t);
    audio.play(60, 0.25);
    audio.advance(200);
    audio.play(62, 0.25);

    audio.advance(50);
    assert.deepEqual(audio.pitches(), [62]);
    audio.advance(200);
    assert.deepEqual(audio.pitches(), []);
});

test('a same-pitch retrigger survives the earlier attack timer, even after a stop', t => {
    const audio = makePlayback(t);
    audio.play(60, 0.25);
    audio.advance(100);
    audio.play(60, 0.25);
    assert.deepEqual(audio.pitches(), [60]);

    audio.advance(150);
    assert.deepEqual(audio.pitches(), [60]);
    audio.stop();
    assert.deepEqual(audio.pitches(), []);
    audio.play(60, 0.25);

    audio.advance(100);
    assert.deepEqual(audio.pitches(), [60]);
    audio.advance(150);
    assert.deepEqual(audio.pitches(), []);
});
