#!/usr/bin/env node
// Independent checks on what render.mjs produced.
//
//   node scripts/verify.mjs [--browser chrome|/path/to/browser]
//                           [--dir <dir>]   check the render in that directory instead of out/
//
// 1. The .excalidraw file has the shape excalidraw.com and the VS Code
//    extension expect, with unique ids, ordered z-indices and intact bindings.
// 2. House style and layout: one font family, nothing smaller than the minimum
//    size, the rules the legend prints hold (nothing starts in the data tier,
//    one two-way arrow, associations and nothing else drawn without an
//    arrowhead), every flow number is grouped with its label and the numbers
//    form one sequence, and no text overlaps another text or an arrow label a
//    box.
// 3. The PNG is a plain image of the expected pixel size (no embedded scene).
// 4. The scene re-opens through Excalidraw's own loader, and loads into the
//    real editor component without anything moving (screenshot: editor.png).
//
// The verdict goes to verify-report.json next to the render, with the hashes
// of the files it was reached on. publish.mjs publishes nothing without it.
import path from "node:path";
import { readFile, rm, writeFile } from "node:fs/promises";
import { fingerprint, hermeticPage, launch, parseArgs, renderFiles, startServer } from "./lib/harness.mjs";

const flags = parseArgs(process.argv.slice(2), {
  flags: ["browser", "dir"],
  usage: "node scripts/verify.mjs [--browser chrome|/path] [--dir <dir>]",
});
const files = flags.dir ? renderFiles(path.resolve(flags.dir)) : renderFiles();

const NUNITO = 6;
const MIN_FONT_SIZE = 14;

const checks = [];
const check = (name, ok, detail = "") => checks.push({ name, ok: Boolean(ok), detail });

// A run that stops half-way must not leave an earlier verdict standing.
await rm(files.verifyReport, { force: true });

// ---- 1. structure ---------------------------------------------------------
const sha256 = await fingerprint(files);
const jsonText = await readFile(files.scene, "utf8");
const scene = JSON.parse(jsonText);
const report = JSON.parse(await readFile(files.report, "utf8"));

check("top-level keys", ["type", "version", "source", "elements", "appState", "files"].every((k) => k in scene), Object.keys(scene).join(","));
check('type is "excalidraw", version 2', scene.type === "excalidraw" && scene.version === 2, `${scene.type} v${scene.version}`);
check("elements is a non-empty array", Array.isArray(scene.elements) && scene.elements.length > 0, `${scene.elements.length} elements`);
check("render reported no problems", report.problems.length === 0 && report.pageErrors.length === 0 && report.externalRequestsBlocked.length === 0, report.problems.slice(0, 3).join("; "));

const REQUIRED = ["id", "type", "x", "y", "width", "height", "angle", "strokeColor", "backgroundColor", "fillStyle", "strokeWidth", "strokeStyle", "roughness", "opacity", "groupIds", "frameId", "index", "roundness", "seed", "version", "versionNonce", "isDeleted", "boundElements", "updated", "link", "locked"];
const incomplete = scene.elements.filter((e) => REQUIRED.some((k) => !(k in e)));
check("every element has all base fields", incomplete.length === 0, incomplete.map((e) => e.id).join(","));

const ids = scene.elements.map((e) => e.id);
check("element ids are unique", new Set(ids).size === ids.length);
// Ids Excalidraw generates itself are random mixed-case strings and would
// change on every run; ours are lowercase slugs such as "rds" or "rds__label".
const randomIds = ids.filter((id) => !id.match(/^[a-z0-9]+(?:[-_]+[a-z0-9]+)*$/));
check("every id is a stable, hand-assigned slug", randomIds.length === 0, randomIds.slice(0, 5).join(","));
const indices = scene.elements.map((e) => e.index);
check("fractional indices are strictly ascending (z-order)", indices.every((v, i) => i === 0 || indices[i - 1] < v));

const byId = new Map(scene.elements.map((e) => [e.id, e]));
const dangling = [];
for (const e of scene.elements) {
  for (const b of e.boundElements ?? []) {
    if (!byId.has(b.id)) dangling.push(`${e.id} -> ${b.id}`);
  }
  if (e.containerId && !byId.has(e.containerId)) dangling.push(`${e.id} -> container ${e.containerId}`);
  for (const side of ["startBinding", "endBinding"]) {
    if (e[side] && !byId.has(e[side].elementId)) dangling.push(`${e.id}.${side} -> ${e[side].elementId}`);
  }
}
check("no dangling bindings or containers", dangling.length === 0, dangling.join("; "));
const bound = scene.elements.filter((e) => e.type === "arrow" && (e.startBinding || e.endBinding));
check(
  "bound shapes back-reference their arrows",
  bound.every((a) => [a.startBinding, a.endBinding].filter(Boolean).every((b) => byId.get(b.elementId)?.boundElements?.some((x) => x.id === a.id))),
  `${bound.length} bound arrows`,
);

// ---- 2. house style -------------------------------------------------------
const texts = scene.elements.filter((e) => e.type === "text");
const offFont = texts.filter((t) => t.fontFamily !== NUNITO);
check("all text is set in Nunito", offFont.length === 0, offFont.slice(0, 3).map((t) => t.id).join(","));
const tooSmall = texts.filter((t) => t.fontSize < MIN_FONT_SIZE);
check(`no text smaller than ${MIN_FONT_SIZE}`, tooSmall.length === 0, tooSmall.slice(0, 3).map((t) => `${t.id}=${t.fontSize}`).join(","));
const rough = scene.elements.filter((e) => e.roughness !== 0);
check("every element is drawn with roughness 0", rough.length === 0, rough.slice(0, 3).map((e) => e.id).join(","));

// The legend prints "Arrow direction = who opens the connection" and "No arrow
// starts in the data tier". Hold the scene to both. An arrowhead at the start
// of an arrow means its far end opens connections too, so a two-headed arrow
// may not touch the data tier at either end, and the control-plane link is the
// only two-headed arrow there is. The legend's own samples are not flows.
const TWO_WAY = ["flow-13-control-plane"];
const dataTier = byId.get("subnets-data");
const inDataTier = ([x, y]) => x >= dataTier.x && x <= dataTier.x + dataTier.width && y >= dataTier.y && y <= dataTier.y + dataTier.height;
const ends = (a) => [a.points[0], a.points.at(-1)].map(([dx, dy]) => [a.x + dx, a.y + dy]);
const flows = scene.elements.filter((e) => e.type === "arrow" && !e.groupIds.includes("legend__group"));
const listIds = (list) => list.map((e) => e.id).join(",");
check("the data tier band exists", dataTier);
if (dataTier) {
  const fromDataTier = flows.filter((a) => inDataTier(ends(a)[0]));
  check("no arrow starts in the data tier", fromDataTier.length === 0, listIds(fromDataTier));
  const twoWayAtDataTier = flows.filter((a) => a.startArrowhead && ends(a).some(inDataTier));
  check("no two-headed arrow touches the data tier", twoWayAtDataTier.length === 0, listIds(twoWayAtDataTier));
}
const twoWay = flows.filter((a) => a.startArrowhead);
check("the control-plane link is the only two-headed arrow", listIds(twoWay) === TWO_WAY.join(","), listIds(twoWay));

// The legend also prints "Association, not traffic" beside a solid line with
// no arrowhead. An association (id assoc-*) with a head would claim a
// direction, and an arrow without one would hide who opens the connection, so
// the two sets have to be the same. An association joins two boxes, wherever
// in the picture it is, and has no place in the numbered sequence of flows.
const isAssociation = (a) => a.id.startsWith("assoc-");
const headless = (a) => !a.startArrowhead && !a.endArrowhead;
const associations = flows.filter(isAssociation);
const wrongHeads = flows.filter((a) => isAssociation(a) !== headless(a));
check("association lines, and only they, have no arrowhead", associations.length > 0 && wrongHeads.length === 0, `${associations.length} associations${wrongHeads.length ? `, wrong: ${listIds(wrongHeads)}` : ""}`);
const notAssociations = associations.filter((a) => a.strokeStyle !== "solid" || !a.startBinding || !a.endBinding || byId.has(`${a.id}__number`));
check("every association is a solid, unnumbered line between two boxes", notAssociations.length === 0, listIds(notAssociations));

// A flow number is a circle, a digit and the label it stands in front of:
// three elements. They share a group so that dragging one in the editor moves
// all three, and a number cannot be left behind or end up beside another label.
const badges = scene.elements.filter((e) => e.type === "ellipse");
const looseBadges = badges.filter((badge) => {
  const [group] = badge.groupIds;
  const members = scene.elements.filter((e) => group && e.groupIds.includes(group)).map((e) => e.id);
  const expected = [badge.id.replace(/__number$/, "__label"), badge.id, `${badge.id}__text`];
  return members.length !== expected.length || expected.some((id) => !members.includes(id));
});
check("every flow number is grouped with its digit and its label", badges.length > 0 && looseBadges.length === 0, `${badges.length} numbers${looseBadges.length ? `, loose: ${listIds(looseBadges)}` : ""}`);
// The numbers are a reading order. Moving a number from one arrow to another
// must not leave a gap in the sequence or the same number on two arrows.
const numbers = badges.map((badge) => Number(byId.get(`${badge.id}__text`)?.text)).sort((a, b) => a - b);
check("flow numbers count up from 1, each used once", numbers.every((n, i) => n === i + 1), numbers.join(","));

// Overlaps are easy to introduce by moving a constant and hard to spot at
// thumbnail size, so check the two that matter: text on text, and an arrow
// label (or its number) on a service box, chip or tag.
const overlap = (a, b, slack = 1) =>
  Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x) > slack &&
  Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y) > slack;
const pairs = (list) => list.flatMap((a, i) => list.slice(i + 1).map((b) => [a, b]));
const textOnText = pairs(texts).filter(([a, b]) => overlap(a, b));
check("no two texts overlap", textOnText.length === 0, textOnText.slice(0, 3).map(([a, b]) => `${a.id} x ${b.id}`).join("; "));
const arrowLabels = scene.elements.filter(
  (e) => e.type === "ellipse" || (e.type === "text" && (byId.get(e.containerId)?.type === "arrow" || e.id.endsWith("__label"))),
);
const boxes = scene.elements.filter((e) => e.type === "rectangle" && e.roundness);
const labelOnBox = arrowLabels.flatMap((l) => boxes.filter((b) => overlap(l, b)).map((b) => `${l.id} x ${b.id}`));
check("no arrow label or number overlaps a box", labelOnBox.length === 0, labelOnBox.slice(0, 3).join("; "));

// ---- 3. PNG ---------------------------------------------------------------
function pngChunkTypes(buf) {
  const types = [];
  for (let off = 8; off < buf.length; off += 12 + buf.readUInt32BE(off)) {
    types.push(buf.toString("latin1", off + 4, off + 8));
  }
  return types;
}
const png = await readFile(files.png);
const isPng = png.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
check("PNG signature", isPng);
if (isPng) {
  const { minX, minY, maxX, maxY } = report.sceneBounds;
  const expectW = Math.round((maxX - minX + 2 * report.padding) * report.scale);
  const expectH = Math.round((maxY - minY + 2 * report.padding) * report.scale);
  const w = png.readUInt32BE(16);
  const h = png.readUInt32BE(20);
  check(`PNG is the scene plus padding at ${report.scale}x`, Math.abs(w - expectW) <= 2 && Math.abs(h - expectH) <= 2, `${w}x${h}, expected ${expectW}x${expectH}`);
  const textChunks = pngChunkTypes(png).filter((t) => ["tEXt", "zTXt", "iTXt"].includes(t));
  check("PNG is plain: no embedded scene or other text chunks", textChunks.length === 0, textChunks.join(","));
}

// ---- 4. browser-side checks -----------------------------------------------
const { server, origin } = await startServer();
const { browser, label } = await launch(flags.browser);
try {
  {
    const { page, blocked, errors } = await hermeticPage(browser, origin);
    await page.goto(`${origin}/`);
    await page.waitForFunction(() => window.__diagramReady === true);
    const reopened = await page.evaluate((t) => window.__diagram.reopen(t), jsonText);
    check("Excalidraw's loader restores every element", reopened.elementCount === scene.elements.length, `${reopened.elementCount}/${scene.elements.length}`);
    check("background is white", reopened.viewBackgroundColor === "#ffffff", reopened.viewBackgroundColor);
    check("loader made no external requests", blocked.length === 0 && errors.length === 0, [...blocked, ...errors].slice(0, 3).join("; "));
  }
  {
    // Device scale 2: at scale 1 the editor draws this scene at about 60% zoom
    // and small text comes out smeared, which makes the screenshot look broken.
    const { page, blocked, errors } = await hermeticPage(browser, origin, { viewport: { width: 1600, height: 1100 }, deviceScaleFactor: 2 });
    await page.goto(`${origin}/editor.html`);
    await page.waitForFunction(() => window.__editorReady === true);
    const r = await page.evaluate((t) => window.__openInEditor(t), jsonText);
    await page.screenshot({ path: files.editorScreenshot });
    check("the editor component loads every element", r.elementsInEditor === r.elementsInFile, `${r.elementsInEditor}/${r.elementsInFile}`);
    check("the editor did not move, resize or rebind anything on load", r.drift.length === 0, r.drift.slice(0, 5).join("; "));
    check("the editor made no external requests and logged no errors", blocked.length === 0 && errors.length === 0, [...blocked, ...errors].slice(0, 3).join("; "));
  }
} finally {
  await browser.close();
  server.close();
}

const failed = checks.filter((c) => !c.ok);
for (const c of checks) {
  console.log(`${c.ok ? "PASS" : "FAIL"}  ${c.name}${c.detail ? `  [${c.detail}]` : ""}`);
}
console.log(`\n${checks.length - failed.length}/${checks.length} checks passed  (browser: ${label})`);
// Read by publish.mjs. Holds nothing machine-specific.
await writeFile(files.verifyReport, JSON.stringify({ passed: failed.length === 0, sha256, checks }, null, 2) + "\n");
process.exitCode = failed.length ? 1 : 0;
