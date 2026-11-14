// iOS Simulator helpers: build, boot, install, and record a scripted demo run.
import { spawn, execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const sh = (cmd, args, opts = {}) =>
  execFileSync(cmd, args, { encoding: 'utf8', maxBuffer: 64 << 20, ...opts }).trim();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export function buildApp({ repoRoot, derivedData, deviceId, log }) {
  log('building iOS app (Debug, Simulator)…');
  const project = path.join(repoRoot, 'ios/HandStrudel/HandStrudel.xcodeproj');
  const logFile = path.join(derivedData, '..', 'xcodebuild.log');
  fs.mkdirSync(path.dirname(logFile), { recursive: true });
  try {
    sh('/bin/sh', ['-c',
      `xcodebuild -project "${project}" -scheme HandStrudel -configuration Debug ` +
      `-destination "platform=iOS Simulator,id=${deviceId}" -derivedDataPath "${derivedData}" ` +
      `build > "${logFile}" 2>&1`]);
  } catch {
    const tail = fs.readFileSync(logFile, 'utf8').split('\n').filter((l) => /error:/.test(l)).slice(0, 15);
    throw new Error(`xcodebuild failed (see ${logFile}):\n${tail.join('\n')}`);
  }
  const app = path.join(derivedData, 'Build/Products/Debug-iphonesimulator/HandStrudel.app');
  if (!fs.existsSync(app)) throw new Error(`built app not found at ${app}`);
  return app;
}

export function resolveDevice(nameOrId) {
  const json = JSON.parse(sh('xcrun', ['simctl', 'list', 'devices', 'available', '-j']));
  const all = Object.values(json.devices).flat();
  const match =
    all.find((d) => d.udid === nameOrId) ||
    all.find((d) => d.name === nameOrId && d.state === 'Booted') ||
    all.find((d) => d.name === nameOrId);
  if (!match) throw new Error(`simulator "${nameOrId}" not found (xcrun simctl list devices)`);
  return match;
}

export function bootDevice(dev, log) {
  if (dev.state !== 'Booted') {
    log(`booting ${dev.name}…`);
    sh('xcrun', ['simctl', 'boot', dev.udid]);
  }
  sh('xcrun', ['simctl', 'bootstatus', dev.udid, '-b']);
  // Clean status bar in case any frame shows it.
  try {
    sh('xcrun', ['simctl', 'status_bar', dev.udid, 'override', '--time', '9:41',
      '--batteryState', 'charged', '--batteryLevel', '100', '--wifiBars', '3', '--cellularBars', '4']);
  } catch { /* older runtimes */ }
  try { sh('xcrun', ['simctl', 'ui', dev.udid, 'appearance', 'dark']); } catch { /* ignore */ }
}

export function installApp(dev, appPath, log) {
  log('installing app…');
  sh('xcrun', ['simctl', 'install', dev.udid, appPath]);
}

/** Device screen size in pixels, read from a screenshot. */
export function screenInfo(dev, workDir) {
  const png = path.join(workDir, 'probe.png');
  sh('xcrun', ['simctl', 'io', dev.udid, 'screenshot', png]);
  const out = sh('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries',
    'stream=width,height', '-of', 'csv=p=0', png]);
  const [w, h] = out.split(',').map(Number);
  return { width: w, height: h, aspect: w / h };
}

/**
 * Launch the app with a demo script, record the screen, and collect the
 * app-side audio capture. Returns paths + sync info.
 */
export async function recordRun({ dev, bundleId, script, outDir, log }) {
  fs.mkdirSync(outDir, { recursive: true });
  const container = sh('xcrun', ['simctl', 'get_app_container', dev.udid, bundleId, 'data']);
  const docs = path.join(container, 'Documents');
  fs.mkdirSync(docs, { recursive: true });
  const demoOut = path.join(docs, 'demo_out');
  fs.rmSync(demoOut, { recursive: true, force: true });
  fs.writeFileSync(path.join(docs, 'demo.json'), JSON.stringify(script));

  try { sh('xcrun', ['simctl', 'terminate', dev.udid, bundleId]); } catch { /* not running */ }
  await sleep(500);

  const rawVideo = path.join(outDir, 'screen.mov');
  fs.rmSync(rawVideo, { force: true });
  log('recording simulator screen…');
  const rec = spawn('xcrun', ['simctl', 'io', dev.udid, 'recordVideo', '--codec=h264', '--force', rawVideo],
    { stdio: ['ignore', 'pipe', 'pipe'] });
  let recStart = null;
  const onData = (buf) => {
    if (recStart === null && /Recording started/i.test(buf.toString())) recStart = Date.now() / 1000;
  };
  rec.stdout.on('data', onData);
  rec.stderr.on('data', onData);
  const spawnTime = Date.now() / 1000;
  for (let i = 0; i < 60 && recStart === null; i++) await sleep(100);
  if (recStart === null) recStart = spawnTime + 0.3;
  await sleep(400);

  log('launching app with demo script…');
  sh('xcrun', ['simctl', 'launch', '--terminate-running-process', dev.udid, bundleId], {
    env: { ...process.env, SIMCTL_CHILD_HANDSTRUDEL_DEMO_SCRIPT: 'demo.json' },
  });

  const deadline = Date.now() + (script.duration + script.startDelay + 90) * 1000;
  const done = path.join(demoOut, 'done');
  while (!fs.existsSync(done)) {
    if (Date.now() > deadline) {
      rec.kill('SIGINT');
      throw new Error('demo run timed out — app never reported done (is the Debug build installed?)');
    }
    await sleep(250);
  }
  await sleep(500);
  rec.kill('SIGINT');
  await new Promise((r) => rec.on('exit', r));

  const meta = JSON.parse(fs.readFileSync(path.join(demoOut, 'meta.json'), 'utf8'));
  const audio = path.join(outDir, 'audio.caf');
  fs.copyFileSync(path.join(demoOut, 'audio.caf'), audio);
  try { sh('xcrun', ['simctl', 'terminate', dev.udid, bundleId]); } catch { /* ignore */ }

  const offset = meta.startEpoch - recStart;
  const info = { rawVideo, audio, offset, duration: script.duration, recStart, startEpoch: meta.startEpoch };
  fs.writeFileSync(path.join(outDir, 'run.json'), JSON.stringify(info, null, 2));
  log(`recorded (video→script offset ${offset.toFixed(2)}s)`);
  return info;
}
