import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");
const distRoot = path.join(projectRoot, "dist");

fs.rmSync(distRoot, { recursive: true, force: true });
fs.mkdirSync(distRoot, { recursive: true });
fs.cpSync(path.join(projectRoot, "index.html"), path.join(distRoot, "index.html"));
fs.cpSync(path.join(projectRoot, "src"), path.join(distRoot, "src"), { recursive: true });

const requiredOutputs = [
  path.join(distRoot, "index.html"),
  path.join(distRoot, "src", "main.js"),
  path.join(distRoot, "src", "styles.css")
];

for (const file of requiredOutputs) {
  if (!fs.existsSync(file)) {
    throw new Error(`Missing build output: ${path.relative(projectRoot, file)}`);
  }
}

console.log(`Built static app to ${path.relative(projectRoot, distRoot)}`);
