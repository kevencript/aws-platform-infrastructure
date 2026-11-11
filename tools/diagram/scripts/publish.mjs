#!/usr/bin/env node
// Copies the render in out/ to the two committed locations.
//
//   node scripts/publish.mjs
//
// This is the only script that writes outside tools/diagram, and it only
// publishes what verify.mjs has passed: the verify report in out/ must say so,
// and the scene and the PNG must still be the files that report was made on.
// A render that was never verified, failed a check or was rendered again
// since is refused.
import path from "node:path";
import { copyFile, mkdir, readFile } from "node:fs/promises";
import { fingerprint, parseArgs, published, renderFiles, repoRoot, toolRoot } from "./lib/harness.mjs";

parseArgs(process.argv.slice(2), { flags: [], usage: "node scripts/publish.mjs" });

const files = renderFiles();
const local = (file) => path.relative(toolRoot, file);
const refuse = (reason) => {
  console.error(`NOT PUBLISHED  ${reason}`);
  process.exit(1);
};

const verdict = await readFile(files.verifyReport, "utf8").then(JSON.parse).catch(() => null);
if (!verdict) {
  refuse(`${local(files.dir)} holds no verify report. Run: npm run render && npm run verify`);
}
const current = await fingerprint(files).catch(() => null);
if (!current || current.scene !== verdict.sha256?.scene || current.png !== verdict.sha256?.png) {
  refuse(`the render in ${local(files.dir)} is not the one that was verified. Run: npm run verify`);
}
if (!verdict.passed) {
  refuse(`the render in ${local(files.dir)} failed verification. Fix the scene, then run: npm run render && npm run verify`);
}

for (const name of ["scene", "png"]) {
  const rendered = await readFile(files[name]);
  const committed = await readFile(published[name]).catch(() => null);
  const changed = !committed?.equals(rendered);
  if (changed) {
    await mkdir(path.dirname(published[name]), { recursive: true });
    await copyFile(files[name], published[name]);
    if (!(await readFile(published[name])).equals(rendered)) {
      refuse(`${path.relative(repoRoot, published[name])} does not match ${local(files[name])} after copying`);
    }
  }
  console.log(`${changed ? "wrote    " : "unchanged"}  ${path.relative(repoRoot, published[name])}`);
}
