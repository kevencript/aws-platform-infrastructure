// Shared plumbing for the scripts in this folder: the scene module and the
// output locations, a local static server for the bundled Excalidraw page,
// browser discovery and a page whose network access is limited to that server.
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { existsSync, readdirSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

export const toolRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
export const repoRoot = path.resolve(toolRoot, "..", "..");
export const webRoot = path.join(toolRoot, "build", "web");

/** The one scene these scripts render. The file names below belong to it. */
export const sceneModule = path.join(toolRoot, "scenes", "architecture.scene.mjs");

/**
 * Files of one render. The default directory is out/, the only one
 * publish.mjs reads; any other directory is a scratch render.
 */
export const renderFiles = (dir = path.join(toolRoot, "out")) => ({
  dir,
  scene: path.join(dir, "architecture.excalidraw"),
  png: path.join(dir, "architecture.png"),
  report: path.join(dir, "render-report.json"),
  verifyReport: path.join(dir, "verify-report.json"),
  editorScreenshot: path.join(dir, "editor.png"),
});

/** The two generated files that are committed. Only publish.mjs writes them. */
export const published = Object.freeze({
  scene: path.join(repoRoot, "docs", "diagrams", "architecture.excalidraw"),
  png: path.join(repoRoot, "diagram.png"),
});

/**
 * SHA-256 of the scene and the PNG of one render. verify.mjs records it with
 * its verdict and publish.mjs compares it, so a verdict only ever counts for
 * the exact files it was reached on.
 */
export async function fingerprint(files) {
  const sha256 = async (file) => createHash("sha256").update(await readFile(file)).digest("hex");
  return { scene: await sha256(files.scene), png: await sha256(files.png) };
}

/**
 * `--key value` pairs, returned as an object.
 *
 * Only the flags in `flags` are accepted. Anything else (an unknown flag, a
 * flag without a value, a bare argument) prints the usage line and exits with
 * status 2, so a mistyped command can never fall through to the defaults.
 */
export function parseArgs(argv, { flags: allowed, usage }) {
  const fail = (message) => {
    console.error(`${message}\nusage: ${usage}`);
    process.exit(2);
  };
  const flags = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      fail(`unexpected argument ${arg}`);
    }
    const name = arg.slice(2);
    if (!allowed.includes(name)) {
      fail(`unknown option ${arg}`);
    }
    const value = argv[++i];
    if (value === undefined || value.startsWith("--")) {
      fail(`option ${arg} needs a value`);
    }
    flags[name] = value;
  }
  return flags;
}

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".woff2": "font/woff2",
  ".json": "application/json",
};

/** Serves build/web on a random loopback port. */
export async function startServer() {
  if (!existsSync(path.join(webRoot, "app.js"))) {
    throw new Error("build/web is missing. Run: npm run bundle");
  }
  const server = http.createServer(async (req, res) => {
    try {
      const urlPath = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
      const file = path.join(webRoot, urlPath === "/" ? "index.html" : urlPath);
      if (!file.startsWith(webRoot + path.sep)) {
        res.writeHead(403).end();
        return;
      }
      const body = await readFile(file);
      res.writeHead(200, {
        "content-type": MIME[path.extname(file)] ?? "application/octet-stream",
        "cache-control": "no-store",
      });
      res.end(body);
    } catch {
      res.writeHead(404).end("not found");
    }
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  return { server, origin: `http://127.0.0.1:${server.address().port}` };
}

// ------------------------------------------------------------------ browser

const home = os.homedir();

// Google Chrome first: it is what the keyword "chrome" means.
const CHROME_PATHS = {
  darwin: [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    path.join(home, "Applications", "Google Chrome.app", "Contents", "MacOS", "Google Chrome"),
  ],
  linux: ["/usr/bin/google-chrome", "/usr/bin/google-chrome-stable", "/opt/google/chrome/chrome"],
};

const CHROMIUM_PATHS = {
  darwin: [
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    path.join(home, "Applications", "Chromium.app", "Contents", "MacOS", "Chromium"),
  ],
  linux: ["/usr/bin/chromium", "/usr/bin/chromium-browser", "/snap/bin/chromium"],
};

const firstExisting = (paths = []) => paths.find((p) => existsSync(p)) ?? null;

function playwrightCacheDir() {
  if (process.env.PLAYWRIGHT_BROWSERS_PATH) {
    return process.env.PLAYWRIGHT_BROWSERS_PATH;
  }
  return process.platform === "darwin"
    ? path.join(home, "Library", "Caches", "ms-playwright")
    : path.join(home, ".cache", "ms-playwright");
}

/**
 * Newest Chromium or headless shell that `playwright install` left in its
 * cache. The folder layout differs per platform and Playwright version, so
 * look up to four levels down for a known executable name, or for the main
 * executable of a macOS app bundle (the only file in its MacOS folder).
 */
function findInPlaywrightCache() {
  const cache = playwrightCacheDir();
  if (!existsSync(cache)) {
    return null;
  }
  const names = new Set(["chrome-headless-shell", "headless_shell", "chrome"]);
  const search = (dir, depth) => {
    const inAppBundle = path.basename(dir) === "MacOS";
    for (const entry of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(dir, entry.name);
      if (entry.isFile() && (names.has(entry.name) || inAppBundle)) {
        return full;
      }
      if (entry.isDirectory() && depth > 0) {
        const found = search(full, depth - 1);
        if (found) {
          return found;
        }
      }
    }
    return null;
  };
  const revision = (name) => Number(name.split("-").pop()) || 0;
  const installs = readdirSync(cache)
    .filter((d) => d.match(/^chromium(_headless_shell)?-\d+$/))
    .sort((a, b) => revision(b) - revision(a) || a.localeCompare(b));
  for (const install of installs) {
    const found = search(path.join(cache, install), 4);
    if (found) {
      return found;
    }
  }
  return null;
}

/**
 * Picks the browser binary. Order:
 *   1. `--browser` flag, then the DIAGRAM_BROWSER environment variable:
 *      a path to a Chromium-family executable, or the keyword `chrome`.
 *   2. An installed Google Chrome, then Chromium, in the standard locations.
 *   3. A Chromium or headless shell in the Playwright cache directory.
 *
 * An explicit executable is always passed to Playwright. playwright-core is
 * pinned and would otherwise insist on the one browser revision it was
 * released with, which is rarely the one that happens to be installed.
 */
export function resolveBrowser(choice = process.env.DIAGRAM_BROWSER) {
  const platform = process.platform;
  if (choice && choice !== "chrome") {
    if (!existsSync(choice)) {
      throw new Error(`browser not found at ${choice}`);
    }
    return choice;
  }
  const chrome = firstExisting(CHROME_PATHS[platform]);
  if (choice === "chrome") {
    if (!chrome) {
      throw new Error("Google Chrome is not installed in a standard location");
    }
    return chrome;
  }
  const found = chrome ?? firstExisting(CHROMIUM_PATHS[platform]) ?? findInPlaywrightCache();
  if (!found) {
    throw new Error(
      "No Chrome or Chromium found. Install one, or point DIAGRAM_BROWSER (or --browser) at an executable.",
    );
  }
  return found;
}

export async function launch(choice) {
  const executablePath = resolveBrowser(choice);
  const browser = await chromium.launch({ headless: true, executablePath });
  // The label goes into console output only, never into a generated file.
  return { browser, label: `${path.basename(executablePath)} ${browser.version()}` };
}

/**
 * New page whose network is restricted to our local server. Any other request
 * is aborted and recorded, so a missing local asset can never be silently
 * papered over by Excalidraw's CDN font fallback.
 */
export async function hermeticPage(browser, origin, contextOptions = {}) {
  const blocked = [];
  const errors = [];
  const context = await browser.newContext({ deviceScaleFactor: 1, ...contextOptions });
  await context.route("**/*", (route) => {
    const url = route.request().url();
    if (url.startsWith(origin) || url.startsWith("data:") || url.startsWith("blob:")) {
      return route.continue();
    }
    blocked.push(url);
    return route.abort();
  });
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("console", (m) => {
    if (m.type() === "error") {
      errors.push(m.text());
    }
  });
  return { page, blocked, errors };
}
