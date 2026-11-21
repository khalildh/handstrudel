// Compile the Swift loader and rules, run them, and write
// src/lib/instruments/swift-goldens.json.
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const here = new URL(".", import.meta.url).pathname;
const repo = join(here, "../..");
const models = join(repo, "ios/HandStrudel/HandStrudel/Models");
const work = mkdtempSync(join(process.env.TMPDIR || tmpdir(), "instrument-goldens-"));
const cases = join(work, "cases.json");
execFileSync("node", [join(here, "make-cases.mjs"), cases], { stdio: "inherit" });
const binary = join(work, "goldens");
execFileSync("swiftc", ["-O", "-o", binary, join(models, "InstrumentSpec.swift"), join(models, "MusicTheory.swift"),
  join(here, "Stubs.swift"), join(here, "main.swift")], { stdio: "inherit" });
const output = execFileSync(binary, [cases], { maxBuffer: 64 * 1024 * 1024 });
writeFileSync(join(repo, "src/lib/instruments/swift-goldens.json"), output);
console.log("wrote src/lib/instruments/swift-goldens.json");
