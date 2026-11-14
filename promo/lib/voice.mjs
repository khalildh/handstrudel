// Voice-over with Kokoro-82M (open-weight TTS, runs locally via kokoro-js).
// Each caption can carry a `say` line spoken when the caption appears, plus a
// closing App Store line over the end card. The music is ducked under the voice.
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

let ttsPromise = null;
async function tts() {
  if (!ttsPromise) {
    ttsPromise = import('kokoro-js').then(({ KokoroTTS }) =>
      KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX', { dtype: 'q8', device: 'cpu' }));
  }
  return ttsPromise;
}

const ff = (args) => execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'inherit' });
const durationOf = (f) => Number(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], { encoding: 'utf8' }));

/** Synthesize one line (cached on disk by text + voice + speed). */
export async function speak(text, { voice, speed, cacheDir }) {
  fs.mkdirSync(cacheDir, { recursive: true });
  const key = crypto.createHash('sha1').update(`${voice}|${speed}|${text}`).digest('hex').slice(0, 16);
  const file = path.join(cacheDir, `${voice}-${key}.wav`);
  if (!fs.existsSync(file)) {
    const model = await tts();
    const audio = await model.generate(text, { voice, speed });
    await audio.save(file);
  }
  return { file, duration: durationOf(file) };
}

/**
 * Build the voice track + ducked music mix for one video.
 * Returns the mixed audio path (48 kHz stereo WAV), or null if no lines.
 */
export async function buildVoiceMix({ spec, config, music, duration, endCardStart, total, dir, log }) {
  const voice = spec.voice ?? config.voice ?? 'af_heart';
  const speed = spec.voiceSpeed ?? config.voiceSpeed ?? 1.08;
  const cacheDir = path.join(dir, '..', '..', 'voice-cache');
  const lines = [];
  for (const [i, c] of (spec.captions ?? []).entries()) {
    if (!c.say) continue;
    const at = c.start + 0.1;
    const next = spec.captions[i + 1]?.start ?? endCardStart;
    const clip = await speak(c.say, { voice, speed, cacheDir });
    if (at + clip.duration > next + 0.3) log?.(`  ⚠ voice line ${i + 1} runs ${(at + clip.duration - next).toFixed(1)}s past its caption: "${c.say}"`);
    lines.push({ at, ...clip });
  }
  const endLine = spec.endSay ?? config.endSay;
  if (endLine) lines.push({ at: endCardStart + 0.25, ...(await speak(endLine, { voice, speed, cacheDir })) });
  if (!lines.length) return null;

  fs.mkdirSync(dir, { recursive: true });
  const out = path.join(dir, 'mix.wav');
  const inputs = ['-i', music];
  lines.forEach((l) => inputs.push('-i', l.file));
  const g = [];
  lines.forEach((l, i) => {
    g.push(`[${i + 1}:a]aresample=48000,aformat=channel_layouts=stereo,highpass=f=90,acompressor=threshold=0.1:ratio=3:attack=5:release=80,loudnorm=I=-14:TP=-1.5:LRA=7,aresample=48000,adelay=${Math.round(l.at * 1000)}:all=1[v${i}]`);
  });
  g.push(`${lines.map((_, i) => `[v${i}]`).join('')}amix=inputs=${lines.length}:normalize=0,apad,atrim=0:${total.toFixed(3)}[voice]`);
  g.push(`[voice]asplit=2[vk][vm]`);
  g.push(`[0:a]aresample=48000,aformat=channel_layouts=stereo,loudnorm=I=-19:TP=-3:LRA=11,aresample=48000,apad,atrim=0:${total.toFixed(3)}[mus]`);
  // Duck the music whenever the voice speaks.
  g.push(`[mus][vk]sidechaincompress=threshold=0.04:ratio=4:attack=20:release=400:makeup=1[duck]`);
  g.push(`[duck][vm]amix=inputs=2:normalize=0,alimiter=limit=0.95[out]`);
  ff([...inputs, '-filter_complex', g.join(';'), '-map', '[out]', '-c:a', 'pcm_f32le', out]);
  log?.(`  voice: ${voice}, ${lines.length} lines`);
  return out;
}
