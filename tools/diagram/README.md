# Architecture diagram

Generates the architecture diagram of this repository from code:

| File | Role |
| --- | --- |
| `scenes/architecture.scene.mjs` | **Source of truth.** Edit this. |
| `../../docs/diagrams/architecture.excalidraw` | Generated. Editable Excalidraw scene. |
| `../../diagram.png` | Generated. Plain PNG at 2x on a white background. |

The scene module is plain JavaScript data: layout constants, then containers,
service boxes, arrows and the legend. A build converts it with Excalidraw's own
code, running in headless Chrome against a locally served bundle, so the
committed scene is exactly what the Excalidraw editor would save.

## Prerequisites

- Node.js 20 or newer
- Google Chrome or Chromium (any recent version)

Network access is only needed for `npm ci`. The build itself is offline: fonts
and scripts come from `node_modules`, and any request that leaves the local
server fails the build.

## Regenerate

```sh
cd tools/diagram
npm ci
npm run build
```

`build` runs four steps in this order. Each can also be run on its own:

| Step | What it does |
| --- | --- |
| `npm run bundle` | Bundles Excalidraw and the two browser scripts in `src/` into `build/web`. Only needed once, and after changing a file in `src/` or a dependency. The scene module and its helpers run in Node.js and are not bundled. |
| `npm run render` | Renders the scene to `out/` and nowhere else. Fails if a text does not fit the room reserved for it, a glyph is missing from the bundled fonts, or the page logs an error. |
| `npm run verify` | Checks the render in `out/`: file structure, bindings, font and size rules, the rules printed in the legend (arrow direction, and association lines being the only lines without an arrowhead), the grouping of flow numbers with their labels and the sequence the numbers form, overlaps, the PNG size, and that the scene loads into the real Excalidraw editor without anything moving. Records its verdict in `out/verify-report.json`. |
| `npm run publish` | Copies the scene and the PNG from `out/` to their committed locations. Refuses unless `verify` passed on exactly those two files, so a render that breaks a rule never reaches the committed files. |

`render` and `verify` take `--dir <dir>` to work in another directory, which is
the way to look at a draft. Only `out/` is ever published:

```sh
node scripts/render.mjs --dir out/draft
node scripts/verify.mjs --dir out/draft
```

Every script rejects options it does not know, so a mistyped flag cannot fall
back to the defaults.

### Check that the committed files are current

```sh
npm run check
```

`check` renders the scene to `out/check`, runs `verify` on that render, and
then compares it with the committed `docs/diagrams/architecture.excalidraw`.
It fails if a check fails, or if the two differ, which means the scene module
was edited without a rebuild. It writes nothing outside `out/check`. Only the
scene is compared, because the bytes of the PNG depend on the browser build.
Run it before committing and in CI, after `npm ci` and `npm run bundle`.

### Browser

The first match is used:

1. `--browser <path>` or the `DIAGRAM_BROWSER` environment variable: a path to
   a Chrome or Chromium executable, or the keyword `chrome`.
2. An installed Google Chrome, then Chromium, in the standard macOS and Linux
   locations.
3. A Chromium or headless shell in the Playwright cache directory.

```sh
DIAGRAM_BROWSER=/usr/bin/chromium npm run build
```

## Editing the diagram

Change `scenes/architecture.scene.mjs` and rebuild. Positions are derived from
the layout constants at the top of that file; `scenes/lib/skeleton.mjs` holds
the colours, text sizes, arrow classes and the shape helpers.

The `.excalidraw` file is build output. It can be opened at
<https://excalidraw.com> or with the Excalidraw extension for VS Code to look
around or to try a layout idea, but changes made there are overwritten by the
next build: carry them back into the scene module.

## Pinned versions

| Package | Version |
| --- | --- |
| `@excalidraw/excalidraw` | 0.18.1 |
| `esbuild` | 0.28.2 |
| `playwright-core` | 1.65.0 |
| `react`, `react-dom` | 18.3.1 |

`playwright-core` only drives the browser. It downloads nothing, and the
browser is always passed to it explicitly, so the browser version is not tied
to the Playwright version.

## Things to know

- **PNG bytes are stable per browser build, not across browser upgrades.** The
  same scene, the same dependencies and the same Chrome build give a
  byte-identical PNG. A different Chrome build may rasterise text slightly
  differently, so expect `diagram.png` to change when the browser does. The
  `.excalidraw` file does not have this problem as long as text measures the
  same.
- **Every glyph in the PNG comes from a bundled font.** The diagram is set in
  Nunito. The bundled Nunito has no arrow glyphs, so the build takes "→" from
  the bundled Liberation Sans, and the numbers on arrows are drawn as circles
  with a digit instead of the Unicode circled digits, which no bundled font
  has. An editor does not know about that substitution: when the `.excalidraw`
  file is opened in one, "→" comes from the editor's fallback font, so the four
  labels that use it (two subnet route lines, the load balancer's second line
  and the label of flow 12) look slightly different from the PNG, and editing
  one of them there measures it again.
- **Most arrow labels are separate text elements.** A label bound to an arrow
  interrupts the line, which cuts dashes and dots in half, so labels sit next
  to their arrows instead: beside a vertical arrow, above a horizontal one.
  A label is grouped with its number, so the two move together in the editor,
  but neither follows an arrow that is dragged there. Only three labels are
  bound to their line: those of the thin association lines between the edge
  services and the load balancer. Those lines are solid, and each label sits
  on a horizontal stretch of its line. The other two association lines, to
  the state bucket and the lock table, are vertical. Excalidraw wraps a bound
  label to the width of its line, and a vertical line has none, so their
  labels sit beside them.
