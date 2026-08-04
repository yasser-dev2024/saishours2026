import { cp, mkdir, readdir, rm, writeFile } from "node:fs/promises";
import { dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const dist = join(root, "dist");
const publicFiles = ["index.html", "style.css", "script.js"];

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
for (const file of publicFiles) {
  await cp(join(root, file), join(dist, file));
}
await cp(join(root, "web_assets"), join(dist, "web_assets"), {
  recursive: true,
});
await writeFile(join(dist, ".nojekyll"), "", "utf8");

async function listFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await listFiles(path)));
    else files.push(path);
  }
  return files;
}

const outputFiles = await listFiles(dist);
if (outputFiles.some((file) => extname(file).toLowerCase() === ".apk")) {
  throw new Error("The website artifact must not contain an APK file.");
}
console.log(`Static site built in ${dist} without embedding the APK.`);
