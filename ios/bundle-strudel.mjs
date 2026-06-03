// Bundle script: creates a single JS file with all Strudel deps for the iOS WebView
import { build } from 'esbuild';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

await build({
    entryPoints: [join(__dirname, 'strudel-entry.mjs')],
    bundle: true,
    // Must be IIFE — bundle is loaded via a plain <script> tag; ESM output
    // leaks top-level helper vars to window and hangs init on iOS.
    format: 'iife',
    outfile: join(__dirname, 'HandStrudel/HandStrudel/Resources/strudel-bundle.js'),
    platform: 'browser',
    target: 'es2020',
    minify: false,
    sourcemap: false,
    // Keep dynamic import for worker
    splitting: false,
});

console.log('Strudel bundle created.');
