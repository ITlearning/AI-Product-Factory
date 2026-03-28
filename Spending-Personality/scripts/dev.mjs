import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");

const DEFAULT_PORT = 4173;
const host = "127.0.0.1";
const port = readPortFromArgs(process.argv.slice(2));

const mimeTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".txt": "text/plain; charset=utf-8"
};

const server = http.createServer((request, response) => {
  const method = request.method ?? "GET";

  if (method !== "GET" && method !== "HEAD") {
    response.writeHead(405, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Method Not Allowed");
    return;
  }

  const filePath = resolveRequestPath(request.url ?? "/");

  if (!filePath) {
    response.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Forbidden");
    return;
  }

  fs.readFile(filePath, (error, content) => {
    if (error) {
      const statusCode = error.code === "ENOENT" ? 404 : 500;
      response.writeHead(statusCode, { "Content-Type": "text/plain; charset=utf-8" });
      response.end(statusCode === 404 ? "Not Found" : "Internal Server Error");
      return;
    }

    response.writeHead(200, {
      "Content-Type": mimeTypes[path.extname(filePath)] ?? "application/octet-stream",
      "Cache-Control": "no-store"
    });

    if (method === "HEAD") {
      response.end();
      return;
    }

    response.end(content);
  });
});

server.listen(port, host, () => {
  console.log(`Spending-Personality dev server running at http://${host}:${port}`);
});

server.on("error", (error) => {
  console.error(error.message);
  process.exitCode = 1;
});

/**
 * @param {string[]} args
 * @returns {number}
 */
function readPortFromArgs(args) {
  const portFlagIndex = args.findIndex((value) => value === "--port");
  const rawPort = portFlagIndex >= 0 ? args[portFlagIndex + 1] : process.env.PORT;
  const parsedPort = Number(rawPort ?? DEFAULT_PORT);

  if (!Number.isInteger(parsedPort) || parsedPort < 1 || parsedPort > 65535) {
    throw new Error(`Invalid port: ${rawPort}`);
  }

  return parsedPort;
}

/**
 * @param {string} requestUrl
 * @returns {string | null}
 */
function resolveRequestPath(requestUrl) {
  const url = new URL(requestUrl, `http://${host}:${port}`);
  const relativePath = decodeURIComponent(url.pathname === "/" ? "/index.html" : url.pathname);
  const filePath = path.resolve(projectRoot, `.${relativePath}`);

  if (!filePath.startsWith(projectRoot)) {
    return null;
  }

  return filePath;
}
