import fs from "node:fs";
import path from "node:path";
import process from "node:process";

async function loadChromium() {
  try {
    const playwright = await import("@playwright/test");
    return playwright.chromium;
  } catch (error) {
    throw new Error(
      "Could not load @playwright/test. Run 'npm install' in the repo root after adding the dependency, then run 'npx playwright install chromium' before capturing screenshots.",
      { cause: error }
    );
  }
}

function parseArgs(argv) {
  const options = {
    baseUrl: "http://127.0.0.1:8080",
    manifest: path.resolve("docs", "screenshots", "pages.json"),
    outputDir: path.resolve("docs", "assets", "screenshots"),
    loginPath: "/login",
    timeoutMs: 15000,
    capture: true,
    syncDocs: true,
    username: process.env.SCREENSHOT_USERNAME || "",
    password: process.env.SCREENSHOT_PASSWORD || ""
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = argv[index + 1];

    if (arg === "--base-url" && next) {
      options.baseUrl = next;
      index += 1;
      continue;
    }

    if (arg === "--manifest" && next) {
      options.manifest = path.resolve(next);
      index += 1;
      continue;
    }

    if (arg === "--output-dir" && next) {
      options.outputDir = path.resolve(next);
      index += 1;
      continue;
    }

    if (arg === "--login-path" && next) {
      options.loginPath = next;
      index += 1;
      continue;
    }

    if (arg === "--timeout-ms" && next) {
      options.timeoutMs = Number.parseInt(next, 10);
      index += 1;
      continue;
    }

    if (arg === "--username" && next) {
      options.username = next;
      index += 1;
      continue;
    }

    if (arg === "--password" && next) {
      options.password = next;
      index += 1;
      continue;
    }

    if (arg === "--capture-only") {
      options.syncDocs = false;
      continue;
    }

    if (arg === "--sync-docs-only") {
      options.capture = false;
      options.syncDocs = true;
    }
  }

  return options;
}

function readManifest(manifestPath) {
  const raw = fs.readFileSync(manifestPath, "utf8");
  const pages = JSON.parse(raw);

  if (!Array.isArray(pages) || pages.length === 0) {
    throw new Error(`Manifest ${manifestPath} does not contain any pages.`);
  }

  return pages;
}

function entryRequiresAuth(entry) {
  return entry.requiresAuth !== false;
}

function normalizeDocsTargets(entry) {
  if (!Array.isArray(entry.docsTargets)) {
    return [];
  }

  return entry.docsTargets.map((target) => {
    if (!target || !target.markdownPath) {
      throw new Error(`Screenshot entry '${entry.name}' contains a docs target without markdownPath.`);
    }

    return {
      markdownPath: path.resolve(target.markdownPath),
      alt: target.alt || entry.alt || `${entry.name} screenshot`,
      caption: target.caption || entry.caption || "",
      heading: target.heading || "## Screenshot"
    };
  });
}

function buildScreenshotBlock({ markerId, alt, relativeImagePath, caption }) {
  const lines = [
    `<!-- AUTO_SCREENSHOT:${markerId}:START -->`,
    `![${alt}](${relativeImagePath})`
  ];

  if (caption) {
    lines.push("");
    lines.push(`*${caption}*`);
  }

  lines.push(`<!-- AUTO_SCREENSHOT:${markerId}:END -->`);
  return `${lines.join("\n")}\n`;
}

function upsertScreenshotBlock(markdownPath, markerId, heading, block) {
  const startMarker = `<!-- AUTO_SCREENSHOT:${markerId}:START -->`;
  const endMarker = `<!-- AUTO_SCREENSHOT:${markerId}:END -->`;
  const original = fs.readFileSync(markdownPath, "utf8");

  if (original.includes(startMarker) && original.includes(endMarker)) {
    const pattern = new RegExp(
      `${startMarker}[\\s\\S]*?${endMarker}\\n?`,
      "m"
    );
    return original.replace(pattern, block);
  }

  const trimmed = original.replace(/\s*$/, "");
  return `${trimmed}\n\n${heading}\n\n${block}`;
}

function syncDocsTargets({ docsTargets, entryName, outputPath }) {
  for (const target of docsTargets) {
    const relativeImagePath = path
      .relative(path.dirname(target.markdownPath), outputPath)
      .split(path.sep)
      .join("/");

    const block = buildScreenshotBlock({
      markerId: entryName,
      alt: target.alt,
      relativeImagePath,
      caption: target.caption
    });

    const updated = upsertScreenshotBlock(
      target.markdownPath,
      entryName,
      target.heading,
      block
    );

    fs.writeFileSync(target.markdownPath, updated, "utf8");
    process.stdout.write(`Updated docs screenshot block in ${target.markdownPath}\n`);
  }
}

async function ensureLoggedIn(page, options) {
  if (!options.username || !options.password) {
    throw new Error(
      "Screenshot capture now requires dashboard credentials. Set SCREENSHOT_USERNAME and SCREENSHOT_PASSWORD, or pass --username and --password."
    );
  }

  const loginUrl = new URL(options.loginPath, options.baseUrl);
  loginUrl.searchParams.set("returnTo", "/");

  await page.goto(loginUrl.toString(), {
    waitUntil: "networkidle",
    timeout: options.timeoutMs
  });

  if (new URL(page.url()).pathname === "/setup") {
    throw new Error(
      "The dashboard redirected screenshot capture to /setup. Create the local screenshot account first, then rerun the capture."
    );
  }

  await page.getByRole("textbox", { name: "Username" }).fill(options.username);
  await page.locator('input[autocomplete="current-password"]').fill(options.password);
  await page.getByRole("button", { name: "Sign In" }).click();

  await page.waitForURL((currentUrl) => {
    const pathname = currentUrl.pathname || "";
    return pathname !== "/login" && pathname !== "/setup";
  }, {
    timeout: options.timeoutMs
  });

  const sessionPayload = await page.evaluate(async () => {
    const response = await fetch("/api/auth/session", {
      credentials: "include"
    });

    return {
      ok: response.ok,
      status: response.status,
      body: await response.json()
    };
  });

  if (!sessionPayload.ok) {
    throw new Error(`Dashboard login succeeded visually but /api/auth/session returned HTTP ${sessionPayload.status}.`);
  }

  const authenticatedPayload = sessionPayload.body;
  if (!authenticatedPayload?.user) {
    throw new Error("Dashboard login did not produce an authenticated session for screenshot capture.");
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const pages = readManifest(options.manifest);
  const chromium = options.capture ? await loadChromium() : null;

  fs.mkdirSync(options.outputDir, { recursive: true });

  const browser = options.capture ? await chromium.launch({ headless: true }) : null;

  try {
    const context = browser
      ? await browser.newContext({
          viewport: { width: 1600, height: 1000 }
        })
      : null;
    const page = context ? await context.newPage() : null;

    if (page) {
      page.setDefaultTimeout(options.timeoutMs);
    }

    if (page && pages.some((entry) => entryRequiresAuth(entry))) {
      await ensureLoggedIn(page, options);
    }

    for (const entry of pages) {
      if (!entry.name || !entry.path) {
        throw new Error("Each screenshot entry must include 'name' and 'path'.");
      }

      const outputPath = path.join(options.outputDir, `${entry.name}.png`);
      const docsTargets = normalizeDocsTargets(entry);

      if (options.capture) {
        const targetUrl = new URL(entry.path, options.baseUrl).toString();

        await page.goto(targetUrl, {
          waitUntil: entry.waitForLoadState || "networkidle",
          timeout: options.timeoutMs
        });

        if (entryRequiresAuth(entry)) {
          const currentPathname = new URL(page.url()).pathname;
          if (currentPathname === "/login" || currentPathname === "/setup") {
            throw new Error(`Screenshot entry '${entry.name}' did not reach ${entry.path}; the browser was redirected to ${currentPathname}, which usually means the authenticated session is missing or expired.`);
          }
        }

        if (entry.waitForSelector) {
          await page.waitForSelector(entry.waitForSelector, {
            timeout: options.timeoutMs
          });
        }

        await page.screenshot({
          path: outputPath,
          fullPage: entry.fullPage !== false
        });

        process.stdout.write(`Captured ${entry.name} -> ${outputPath}\n`);
      }

      if (options.syncDocs && docsTargets.length > 0) {
        syncDocsTargets({
          docsTargets,
          entryName: entry.name,
          outputPath
        });
      }
    }
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);

  if (error.cause && error.cause.message) {
    process.stderr.write(`${error.cause.message}\n`);
  }

  process.exitCode = 1;
});
