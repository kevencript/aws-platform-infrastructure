// Bundles the locally installed @excalidraw/excalidraw (plus React) into a
// self-contained static site under build/web, so rendering never touches a CDN.
//
//   node scripts/bundle.mjs
import { build } from "esbuild";
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "./lib/harness.mjs";

// Takes no options. Checked before anything is deleted or written.
parseArgs(process.argv.slice(2), { flags: [], usage: "node scripts/bundle.mjs" });

const toolRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outdir = path.join(toolRoot, "build", "web");
const pkgDir = path.join(toolRoot, "node_modules", "@excalidraw", "excalidraw");
const pkg = JSON.parse(await readFile(path.join(pkgDir, "package.json"), "utf8"));

await rm(outdir, { recursive: true, force: true });
await mkdir(outdir, { recursive: true });

const result = await build({
  absWorkingDir: toolRoot,
  // app    = headless renderer, driven by scripts/render.mjs
  // editor = the real <Excalidraw> component, used only by scripts/verify.mjs
  entryPoints: { app: "src/browser-entry.js", editor: "src/editor-entry.js" },
  outdir,
  bundle: true,
  format: "esm",
  splitting: true,
  platform: "browser",
  target: "chrome120",
  conditions: ["production"],
  define: {
    "process.env.NODE_ENV": '"production"',
    "process.env.IS_PREACT": '"false"',
  },
  loader: { ".woff2": "file" },
  legalComments: "none",
  metafile: true,
  logLevel: "warning",
});

// Fonts are fetched at runtime relative to window.EXCALIDRAW_ASSET_PATH.
await cp(path.join(pkgDir, "dist", "prod", "fonts"), path.join(outdir, "fonts"), {
  recursive: true,
});

// Both globals must be set before the bundle is evaluated.
// EXCALIDRAW_EXPORT_SOURCE becomes the "source" field of the saved scene.
// Without it Excalidraw writes the page origin, which here is a loopback
// address with a random port and would differ on every run.
const page = (title, head, body) => `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>${title}</title>
    <script>
      window.EXCALIDRAW_ASSET_PATH = "/";
      window.EXCALIDRAW_EXPORT_SOURCE = "https://excalidraw.com";
    </script>${head}
  </head>
  <body>
    ${body}
  </body>
</html>
`;

await writeFile(
  path.join(outdir, "index.html"),
  page("diagram renderer", "", '<script type="module" src="/app.js"></script>'),
);
await writeFile(
  path.join(outdir, "editor.html"),
  page(
    "diagram editor check",
    '\n    <link rel="stylesheet" href="/editor.css" />\n    <style>html, body, #root { height: 100%; margin: 0; }</style>',
    '<div id="root"></div>\n    <script type="module" src="/editor.js"></script>',
  ),
);

const emitted = Object.values(result.metafile.outputs);
const megabytes = emitted.reduce((n, o) => n + o.bytes, 0) / 1e6;
console.log(
  `bundled @excalidraw/excalidraw@${pkg.version} -> ${path.relative(toolRoot, outdir)} ` +
    `(${emitted.length} files, ${megabytes.toFixed(1)} MB)`,
);
