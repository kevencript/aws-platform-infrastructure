#!/usr/bin/env node
// Is the committed diagram correct and up to date with the scene module?
//
//   node scripts/check.mjs [--browser chrome|/path/to/browser]
//
// Renders the scene to out/check, runs every check of verify.mjs on that
// render, then fails if it differs from the committed
// docs/diagrams/architecture.excalidraw. Writes nothing outside out/check.
// Only the scene is compared: the bytes of the PNG depend on the browser build.
import path from "node:path";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { parseArgs, published, renderFiles, repoRoot, toolRoot } from "./lib/harness.mjs";

const flags = parseArgs(process.argv.slice(2), {
  flags: ["browser"],
  usage: "node scripts/check.mjs [--browser chrome|/path]",
});

const fresh = renderFiles(path.join(toolRoot, "out", "check"));
for (const script of ["render.mjs", "verify.mjs"]) {
  const step = spawnSync(
    process.execPath,
    [path.join(toolRoot, "scripts", script), "--dir", fresh.dir, ...(flags.browser ? ["--browser", flags.browser] : [])],
    { stdio: "inherit" },
  );
  if (step.status !== 0) {
    console.error(`\nFAILED  ${script} on the scene module, see above`);
    process.exit(step.status ?? 1);
  }
}

const committed = await readFile(published.scene).catch(() => null);
const name = path.relative(repoRoot, published.scene);
if (committed?.equals(await readFile(fresh.scene))) {
  console.log(`\nup to date  ${name} matches the scene module`);
} else {
  console.error(`\nOUT OF DATE  ${name} ${committed ? "differs from what the scene module renders" : "is missing"}. Run: npm run build`);
  process.exitCode = 1;
}
