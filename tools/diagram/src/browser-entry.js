// Runs INSIDE headless Chrome. Bundled by scripts/bundle.mjs into build/web/.
// Exposes a small API on window.__diagram that scripts/render.mjs and
// scripts/verify.mjs drive.
import {
  convertToExcalidrawElements,
  exportToBlob,
  exportToCanvas,
  serializeAsJSON,
  restoreElements,
  loadFromBlob,
  FONT_FAMILY,
} from "@excalidraw/excalidraw";

const FAMILY_NAME_BY_ID = Object.fromEntries(
  Object.entries(FONT_FAMILY).map(([name, id]) => [id, name]),
);

const blobToBase64 = (blob) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(reader.error);
    reader.onload = () => resolve(String(reader.result).split(",", 2)[1]);
    reader.readAsDataURL(blob);
  });

// Small deterministic 31-bit hash so seeds and nonces do not change between runs.
const hash31 = (str) => {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0) % 2147483647;
};

/**
 * The bundled Nunito has no arrows block, so "→" would be drawn from
 * whichever system font has one and the picture would change from machine to
 * machine. Liberation Sans ships in the same package and has those glyphs.
 * Exposing them under the Nunito family name, limited to that block by
 * unicode-range, keeps every glyph in the diagram coming from a bundled file.
 */
const ARROW_GLYPHS = {
  family: "Nunito",
  source: 'url("/fonts/Liberation/LiberationSans-Regular.woff2")',
  unicodeRange: "U+2190-21FF",
};

function addArrowGlyphs() {
  const { family, source, unicodeRange } = ARROW_GLYPHS;
  const sibling = [...document.fonts].find((f) => f.family.replace(/"/g, "") === family);
  if (!sibling) {
    throw new Error(`${family} is not registered; cannot add arrow glyphs to it`);
  }
  // The browser only combines faces by unicode-range when weight, style and
  // stretch are identical. A face with different values forms a variant of
  // its own, wins the match for regular text and hides the real Nunito.
  const { weight, style, stretch } = sibling;
  document.fonts.add(new FontFace(family, source, { unicodeRange, weight, style, stretch }));
}

/** True if code point `cp` falls inside a CSS unicode-range list. */
function inUnicodeRange(range, cp) {
  return range.split(",").some((part) => {
    const m = part.trim().match(/^U\+([0-9A-F?]+)(?:-([0-9A-F]+))?$/i);
    if (!m) {
      return false;
    }
    const lo = parseInt(m[1].replace(/\?/g, "0"), 16);
    const hi = m[2] ? parseInt(m[2], 16) : parseInt(m[1].replace(/\?/g, "F"), 16);
    return cp >= lo && cp <= hi;
  });
}

/**
 * Characters no loaded face of `family` declares. The browser would still
 * draw them, from a system font, which is exactly what must not happen.
 */
function uncoveredCharacters(family, text) {
  const ranges = [...document.fonts]
    .filter((f) => f.family.replace(/"/g, "") === family && f.status === "loaded")
    .map((f) => f.unicodeRange);
  return Array.from(new Set(Array.from(text))).filter(
    (ch) => ch !== "\n" && !ranges.some((r) => inUnicodeRange(r, ch.codePointAt(0))),
  );
}

/**
 * Excalidraw only puts its @font-face objects into document.fonts lazily, the
 * first time an export runs. convertToExcalidrawElements() measures text with
 * canvas.measureText, so if it runs before the fonts are in, every label is
 * measured against a fallback font and containers come out the wrong size.
 * So: (1) run a throwaway export to make Excalidraw register its faces,
 *     (2) explicitly load each family for the exact characters we will draw,
 *     (3) only then convert the skeleton.
 */
async function preloadFonts(familyIds, text) {
  const probe = convertToExcalidrawElements([
    { type: "rectangle", x: 0, y: 0, width: 10, height: 10 },
  ]);
  await exportToCanvas({ elements: probe, files: null });
  addArrowGlyphs();

  const chars = Array.from(new Set(Array.from(text + " "))).join("");
  const report = [];
  for (const id of familyIds) {
    const name = FAMILY_NAME_BY_ID[id];
    if (!name) {
      throw new Error(`Unknown fontFamily id ${id}`);
    }
    const font = `20px "${name}"`;
    const faces = await document.fonts.load(font, chars);
    report.push({ id, name, facesLoaded: faces.length, uncovered: uncoveredCharacters(name, chars) });
  }
  await document.fonts.ready;
  return report;
}

/** Font families and characters the skeleton uses. Every text names its family. */
function collectFontUsage(skeleton) {
  const families = new Set();
  let text = "";
  for (const el of skeleton) {
    for (const t of [el.type === "text" ? el : null, el.label]) {
      if (t?.text) {
        families.add(t.fontFamily);
        text += t.text;
      }
    }
  }
  return { families: [...families], text };
}

/**
 * When an arrow has start/end bindings, convertToExcalidrawElements() nudges
 * its first and last point by 0.5px (after it has computed the binding). On an
 * orthogonal polyline that leaves the first segment visibly off-axis, so put
 * back exactly the geometry the scene asked for.
 */
function undoEndpointNudge(skeleton, elements) {
  const byId = new Map(elements.map((e) => [e.id, e]));
  for (const s of skeleton) {
    if ((s.type !== "arrow" && s.type !== "line") || !Array.isArray(s.points) || !s.id) {
      continue;
    }
    const el = byId.get(s.id);
    if (!el) {
      continue;
    }
    const xs = s.points.map((p) => p[0]);
    const ys = s.points.map((p) => p[1]);
    Object.assign(el, {
      x: s.x,
      y: s.y,
      points: s.points.map((p) => [p[0], p[1]]),
      width: Math.max(...xs) - Math.min(...xs),
      height: Math.max(...ys) - Math.min(...ys),
    });
  }
}

/**
 * Scene helpers attach a `layout` hint to elements whose final position
 * depends on measured text (see scenes/lib/skeleton.mjs). Hints are not
 * Excalidraw properties, so they are split off before conversion...
 */
function splitLayoutHints(skeleton) {
  const hints = new Map();
  const clean = skeleton.map((el) => {
    if (!el.layout) {
      return el;
    }
    const { layout, ...rest } = el;
    hints.set(el.id, layout);
    return rest;
  });
  return { clean, hints };
}

/** ...and applied once every element has its measured size. */
function applyLayoutHints(hints, elements) {
  const byId = new Map(elements.map((e) => [e.id, e]));
  const problems = [];
  const resolve = (id, key) => {
    const el = byId.get(id);
    const ref = byId.get(hints.get(id)[key]);
    if (!ref) {
      problems.push(`${id}: layout hint ${key} refers to missing element ${hints.get(id)[key]}`);
    }
    return [el, ref];
  };
  // Order matters: a number badge is placed left of its label first, then the
  // digit is centred in the badge.
  for (const [id, hint] of hints) {
    if (hint.leftOf) {
      const [el, ref] = resolve(id, "leftOf");
      if (ref) {
        el.x = ref.x - (hint.gap ?? 0) - el.width;
        el.y = ref.y + (ref.height - el.height) / 2;
      }
    }
  }
  for (const [id, hint] of hints) {
    if (hint.centerIn) {
      const [el, ref] = resolve(id, "centerIn");
      if (ref) {
        el.x = ref.x + (ref.width - el.width) / 2;
        el.y = ref.y + (ref.height - el.height) / 2;
      }
    }
  }
  for (const [id, hint] of hints) {
    if (hint.fitIn) {
      const [el, ref] = resolve(id, "fitIn");
      // The margin is the horizontal padding. Vertically the text only has to
      // stay inside: chips and tags are barely taller than one line.
      const m = hint.margin ?? 0;
      if (ref) {
        const over = Math.max(
          ref.x + m - el.x,
          el.x + el.width - (ref.x + ref.width - m),
          ref.y - el.y,
          el.y + el.height - (ref.y + ref.height),
        );
        if (over > 0) {
          problems.push(`text ${JSON.stringify(el.text)} does not fit in ${ref.id} with a ${m}px margin (over by ${over.toFixed(1)}px)`);
        }
      }
    }
    if (hint.endsBefore !== undefined) {
      const el = byId.get(id);
      const over = el.x + el.width - hint.endsBefore;
      if (over > 0) {
        problems.push(`text ${JSON.stringify(el.text)} runs ${over.toFixed(1)}px past x=${hint.endsBefore}, the end of the room reserved for it`);
      }
    }
  }
  return problems;
}

// Written into every element's `updated` field instead of the current time.
const FIXED_TIMESTAMP = 1700000000000;

/** Make id-derived fields stable so the committed .excalidraw diffs cleanly. */
function makeDeterministic(elements) {
  for (const el of elements) {
    el.seed = hash31(`${el.id}:seed`);
    el.versionNonce = hash31(`${el.id}:nonce`);
    el.version = 1;
    el.updated = FIXED_TIMESTAMP;
  }
  return elements;
}

/** Sanity checks that would otherwise only be visible by eyeballing the PNG. */
function inspect(elements) {
  const byId = new Map(elements.map((e) => [e.id, e]));
  const problems = [];
  const ctx = document.createElement("canvas").getContext("2d");

  for (const el of elements) {
    if (el.type === "text") {
      ctx.font = `${el.fontSize}px "${FAMILY_NAME_BY_ID[el.fontFamily]}"`;
      const widest = Math.max(...el.text.split("\n").map((line) => ctx.measureText(line).width));
      if (Math.abs(widest - el.width) > 1.5) {
        problems.push(
          `text "${el.text}" stored width ${el.width.toFixed(1)} but renders at ${widest.toFixed(1)} (font not loaded at measure time?)`,
        );
      }
      // Bound text belongs to an arrow: the scene helpers never bind text to a shape.
      if (el.containerId && !byId.has(el.containerId)) {
        problems.push(`text "${el.text}" has missing container ${el.containerId}`);
      }
    }
    if (el.type === "arrow") {
      for (const side of ["startBinding", "endBinding"]) {
        const b = el[side];
        if (!b) {
          continue;
        }
        const target = byId.get(b.elementId);
        if (!target) {
          problems.push(`arrow ${el.id} ${side} points at missing ${b.elementId}`);
        } else if (!target.boundElements?.some((x) => x.id === el.id)) {
          problems.push(`${target.id} does not list arrow ${el.id} in boundElements`);
        }
      }
    }
  }
  return problems;
}

async function render({ skeleton: rawSkeleton, options = {} }) {
  const { scale = 2, padding = 24, background = "#ffffff" } = options;

  const { clean: skeleton, hints } = splitLayoutHints(rawSkeleton);
  const usage = collectFontUsage(skeleton);
  const fonts = await preloadFonts(usage.families, usage.text);

  const converted = convertToExcalidrawElements(skeleton, { regenerateIds: false });
  undoEndpointNudge(skeleton, converted);
  const layoutProblems = applyLayoutHints(hints, converted);
  // restoreElements() is what the editor runs on every file it opens. Running
  // it here means the saved file is already in the editor's canonical form
  // (the skeleton converter leaves arrow points un-normalised), so opening and
  // saving it in the app does not rewrite every element.
  const restored = restoreElements(converted, null, {
    refreshDimensions: false,
    repairBindings: true,
  });
  const elements = makeDeterministic(restored);

  const sceneAppState = {
    viewBackgroundColor: background,
    gridSize: 20,
    gridStep: 5,
    gridModeEnabled: false,
  };
  const json = serializeAsJSON(elements, sceneAppState, {}, "local");

  const pngBlob = await exportToBlob({
    elements,
    appState: {
      ...sceneAppState,
      exportBackground: true,
      exportWithDarkMode: false,
      exportEmbedScene: false,
      exportScale: scale,
    },
    files: {},
    mimeType: "image/png",
    exportPadding: padding,
    // The public exportToBlob ignores appState.exportScale; the scale that is
    // actually applied is the one returned here.
    getDimensions: (width, height) => ({
      width: Math.round(width * scale),
      height: Math.round(height * scale),
      scale,
    }),
  });

  const [minX, minY, maxX, maxY] = elements.reduce(
    ([a, b, c, d], e) => [
      Math.min(a, e.x),
      Math.min(b, e.y),
      Math.max(c, e.x + e.width),
      Math.max(d, e.y + e.height),
    ],
    [Infinity, Infinity, -Infinity, -Infinity],
  );

  return {
    json,
    pngBase64: await blobToBase64(pngBlob),
    report: {
      elementCount: elements.length,
      byType: elements.reduce((acc, e) => ((acc[e.type] = (acc[e.type] || 0) + 1), acc), {}),
      sceneBounds: { minX, minY, maxX, maxY },
      scale,
      padding,
      fonts,
      problems: [
        ...fonts.flatMap((f) => f.uncovered.map((ch) => `"${ch}" is not in the bundled ${f.name} font and would be drawn from a system font`)),
        ...layoutProblems,
        ...inspect(elements),
      ],
    },
  };
}

/** Re-open a saved .excalidraw exactly as the app would. */
async function reopen(jsonText) {
  const blob = new Blob([jsonText], { type: "application/vnd.excalidraw+json" });
  const scene = await loadFromBlob(blob, null, null);
  return {
    elementCount: scene.elements.length,
    viewBackgroundColor: scene.appState.viewBackgroundColor,
  };
}

window.__diagram = { render, reopen };
window.__diagramReady = true;
