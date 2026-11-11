#!/usr/bin/env node
// Scene module -> out/architecture.excalidraw + out/architecture.png.
//
//   node scripts/render.mjs [--browser chrome|/path/to/browser]
//                           [--dir <dir>]   render there instead of out/
//
// The scene module default-exports a function returning
//   { skeleton, options: { scale, padding, background } }
// Writes nothing outside the output directory: the committed files are
// written by publish.mjs, once verify.mjs has passed this render.
// Exits non-zero if a text does not fit the room reserved for it, a glyph is
// missing from the bundled fonts, the page logs an error or a request leaves
// the local server.
import path from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { hermeticPage, launch, parseArgs, renderFiles, sceneModule, startServer } from "./lib/harness.mjs";

const flags = parseArgs(process.argv.slice(2), {
  flags: ["browser", "dir"],
  usage: "node scripts/render.mjs [--browser chrome|/path] [--dir <dir>]",
});
const target = flags.dir ? renderFiles(path.resolve(flags.dir)) : renderFiles();

const { default: buildScene } = await import(pathToFileURL(sceneModule).href);
const scene = await buildScene();

const { server, origin } = await startServer();
const { browser, label } = await launch(flags.browser);
try {
  const { page, blocked, errors } = await hermeticPage(browser, origin);
  await page.goto(`${origin}/`);
  await page.waitForFunction(() => window.__diagramReady === true, null, { timeout: 60000 });

  const result = await page.evaluate((s) => window.__diagram.render(s), {
    skeleton: scene.skeleton,
    options: scene.options,
  });

  const png = Buffer.from(result.pngBase64, "base64");
  await mkdir(target.dir, { recursive: true });
  await writeFile(target.scene, result.json + "\n");
  await writeFile(target.png, png);
  // Read back by verify.mjs. Holds nothing machine-specific.
  const report = {
    ...result.report,
    png: { width: png.readUInt32BE(16), height: png.readUInt32BE(20), bytes: png.length },
    externalRequestsBlocked: blocked,
    pageErrors: errors,
  };
  await writeFile(target.report, JSON.stringify(report, null, 2) + "\n");

  const { minX, minY, maxX, maxY } = report.sceneBounds;
  console.log(`browser   ${label}`);
  console.log(`elements  ${report.elementCount}  ${JSON.stringify(report.byType)}`);
  console.log(`scene     ${Math.round(maxX - minX)} x ${Math.round(maxY - minY)} units`);
  console.log(`png       ${report.png.width} x ${report.png.height} px, ${report.png.bytes} bytes`);
  const here = path.relative(process.cwd(), target.dir) || ".";
  console.log(`rendered  ${here.startsWith("..") ? target.dir : here}`);

  const failures = [...report.problems, ...blocked.map((u) => `blocked request: ${u}`), ...errors.map((e) => `page error: ${e}`)];
  if (failures.length) {
    for (const f of failures) {
      console.error(`PROBLEM   ${f}`);
    }
    console.error(`\n${failures.length} problem(s). The files are left in place for inspection.`);
    process.exitCode = 1;
  }
} finally {
  await browser.close();
  server.close();
}
