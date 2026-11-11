// Used by scripts/verify.mjs only. Mounts the real <Excalidraw> editor
// component (the one excalidraw.com and the VS Code extension embed), loads a
// generated .excalidraw file into it the way opening the file would, and
// reports anything the editor moved, resized or re-bound while loading.
import React from "react";
import { createRoot } from "react-dom/client";
import { Excalidraw, FONT_FAMILY, loadFromBlob } from "@excalidraw/excalidraw";
import "@excalidraw/excalidraw/index.css";

const FAMILY_NAME_BY_ID = Object.fromEntries(
  Object.entries(FONT_FAMILY).map(([name, id]) => [id, name]),
);
const FONT_TIMEOUT_MS = 30000;

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(() => resolve()));

/**
 * Resolves once the editor has loaded a face of every font family the scene
 * uses and no font is still loading. The editor registers its fonts and
 * starts loading them when it initialises the scene, a moment after mounting,
 * so document.fonts.ready alone could resolve before that has begun.
 */
async function sceneFontsLoaded(elements) {
  const families = [...new Set(elements.filter((e) => e.type === "text").map((e) => FAMILY_NAME_BY_ID[e.fontFamily]))];
  const missing = () =>
    families.filter((name) => ![...document.fonts].some((f) => f.family.replace(/"/g, "") === name && f.status === "loaded"));
  const deadline = performance.now() + FONT_TIMEOUT_MS;
  while (missing().length) {
    if (performance.now() > deadline) {
      throw new Error(`the editor did not load: ${missing().join(", ")}`);
    }
    await nextFrame();
  }
  await document.fonts.ready;
}

window.__openInEditor = async (jsonText) => {
  const blob = new Blob([jsonText], { type: "application/vnd.excalidraw+json" });
  const scene = await loadFromBlob(blob, null, null);
  let api = null;
  await new Promise((resolve) => {
    createRoot(document.getElementById("root")).render(
      React.createElement(Excalidraw, {
        initialData: { ...scene, scrollToContent: true },
        excalidrawAPI: (instance) => {
          api = instance;
          resolve();
        },
      }),
    );
  });
  // Text is re-measured and redrawn when its font arrives, so compare and
  // take the screenshot only after that, and after the frames that paint the
  // final view.
  await sceneFontsLoaded(scene.elements);
  api.scrollToContent(api.getSceneElements(), {
    fitToViewport: true,
    viewportZoomFactor: 0.9,
    animate: false,
  });
  await nextFrame();
  await nextFrame();

  const live = new Map(api.getSceneElements().map((e) => [e.id, e]));
  const original = JSON.parse(jsonText).elements;
  const drift = [];
  for (const o of original) {
    const l = live.get(o.id);
    if (!l) {
      drift.push(`${o.id}: missing in editor`);
      continue;
    }
    for (const k of ["x", "y", "width", "height"]) {
      if (Math.abs(l[k] - o[k]) > 0.01) {
        drift.push(`${o.id}.${k}: file ${o[k]} -> editor ${l[k]}`);
      }
    }
    if (o.type === "arrow") {
      if (JSON.stringify(l.points) !== JSON.stringify(o.points)) {
        drift.push(`${o.id}.points changed`);
      }
      for (const side of ["startBinding", "endBinding"]) {
        if ((o[side]?.elementId ?? null) !== (l[side]?.elementId ?? null)) {
          drift.push(`${o.id}.${side} changed`);
        }
      }
    }
  }
  return { elementsInEditor: live.size, elementsInFile: original.length, drift };
};
window.__editorReady = true;
