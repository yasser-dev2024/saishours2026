import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const expectedVersion = "2.1.1";
const expectedFile = `Sayes-Alkhayl-v${expectedVersion}-universal.apk`;
const expectedUrl =
  `https://github.com/yasser-dev2024/saishours2026/raw/refs/heads/main/releases/${expectedFile}`;
const [page, script, styles, workflow, packageSource, builder] =
  await Promise.all([
    readFile(new URL("../index.html", import.meta.url), "utf8"),
    readFile(new URL("../script.js", import.meta.url), "utf8"),
    readFile(new URL("../style.css", import.meta.url), "utf8"),
    readFile(
      new URL("../.github/workflows/deploy-pages.yml", import.meta.url),
      "utf8",
    ),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../tools/build_web.mjs", import.meta.url), "utf8"),
  ]);

const downloadTags = [
  ...page.matchAll(/<a\b[^>]*class="[^"]*\bdownload-link\b[^"]*"[^>]*>/g),
].map((match) => match[0]);
const hrefs = downloadTags.map(
  (tag) => tag.match(/\bhref="([^"]+)"/)?.[1] ?? "",
);

test("renders Android download controls", () => {
  assert.equal(downloadTags.length, 1);
  assert.match(page, /تحميل (?:Android|التطبيق|سايس الخيل)/);
});

test("uses one official GitHub Raw source for every Android control", () => {
  assert.deepEqual([...new Set(hrefs)], [expectedUrl]);
});

test("uses raw instead of blob or GitHub Releases URLs", () => {
  assert.match(expectedUrl, /\/raw\/refs\/heads\/main\//);
  assert.doesNotMatch(page, /github\.com\/[^"']+\/blob\//);
  assert.doesNotMatch(page, /github\.com\/[^"']+\/releases\/download\//);
});

test("publishes only the current universal APK version", () => {
  assert.match(page, new RegExp(expectedFile.replaceAll(".", "\\.")));
  assert.doesNotMatch(page, /href="[^"]*Sayes-Alkhayl-v(?:2\.0|2\.1\.0)[^"]*\.apk"/);
});

test("keeps the download file name consistent", () => {
  for (const tag of downloadTags) {
    assert.match(tag, new RegExp(`download="${expectedFile.replaceAll(".", "\\.")}"`));
  }
});

test("does not present fake iPhone packages or archives", () => {
  assert.doesNotMatch(page, /\.(?:zip|ipa|plist)(?:["?#])/i);
  assert.doesNotMatch(page, /itms-services:|iphone-button|IPHONE_URL/i);
});

test("keeps immediate visual feedback when download is pressed", () => {
  assert.match(script, /classList\.add\('download-started'\)/);
  assert.match(styles, /\.download-link\.download-started\s*\{/);
});

test("builds and uploads dist rather than releases", () => {
  assert.match(workflow, /npm run build/);
  assert.match(workflow, /path: \.\/dist/);
  assert.doesNotMatch(workflow, /cp -R web_assets releases|path: \.\/_site/);
});

test("the site builder rejects embedded APK files", () => {
  assert.match(builder, /extname\(file\).*=== "\.apk"/);
  assert.doesNotMatch(builder, /join\(root, "releases"\)/);
});

test("npm exposes distribution tests and the guarded build", () => {
  const manifest = JSON.parse(packageSource);
  assert.equal(manifest.scripts["test:web"], "node --test web-tests/*.test.mjs");
  assert.match(manifest.scripts.build, /npm run test:web/);
  assert.match(manifest.scripts.build, /tools\/build_web\.mjs/);
});
