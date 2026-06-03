// Bundle script: creates a single JS file with all Strudel deps for the iOS WebView
import { build } from 'esbuild';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

await build({
    entryPoints: [join(__dirname, 'strudel-entry.mjs')],
    bundle: true,
    // IIFE so top-level helper `var`s don't leak to window (Hydra defines
    // some of the same names — colliding kept _moduleReady from firing).
    format: 'iife',
    outfile: join(__dirname, 'HandStrudel/HandStrudel/Resources/strudel-bundle.js'),
    platform: 'browser',
    target: 'es2020',
    minify: false,
    sourcemap: false,
    splitting: false,
});

console.log('Strudel bundle created.');
