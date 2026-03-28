import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const defaultProjectRoot = path.resolve(__dirname, "..");

export const DEFAULT_PORT = 4173;
export const DEFAULT_HOST = "127.0.0.1";

const mimeTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".txt": "text/plain; charset=utf-8"
};

if (isDirectRun()) {
  const port = readPortFromArgs(process.argv.slice(2));
  const server = createDevServer({ host: DEFAULT_HOST, port, projectRoot: defaultProjectRoot });

  server.listen(port, DEFAULT_HOST, () => {
    console.log(`Spending-Personality dev server running at http://${DEFAULT_HOST}:${port}`);
  });

  server.on("error", (error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

/**
 * @param {{ host?: string, port?: number, projectRoot?: string }} [options]
 */
export function createDevServer(options = {}) {
  return http.createServer(createRequestHandler(options));
}

/**
 * @param {{ host?: string, port?: number, projectRoot?: string }} [options]
 */
export function createRequestHandler(options = {}) {
  const host = options.host ?? DEFAULT_HOST;
  const port = options.port ?? DEFAULT_PORT;
  const projectRoot = path.resolve(options.projectRoot ?? defaultProjectRoot);

  return (request, response) => {
    const method = request.method ?? "GET";

    if (method !== "GET" && method !== "HEAD") {
      response.writeHead(405, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Method Not Allowed");
      return;
    }

    let filePath;

    try {
      filePath = resolveRequestPath(request.url ?? "/", { host, port, projectRoot });
    } catch {
      response.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Bad Request");
      return;
    }

    if (!filePath) {
      response.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Forbidden");
      return;
    }

    try {
      filePath = resolveSafeFilePath(projectRoot, filePath);
    } catch {
      response.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Internal Server Error");
      return;
    }

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
  };
}

/**
 * @param {string[]} args
 * @returns {number}
 */
export function readPortFromArgs(args) {
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
 * @param {{ host?: string, port?: number, projectRoot?: string }} [options]
 * @returns {string | null}
 */
export function resolveRequestPath(requestUrl, options = {}) {
  const host = options.host ?? DEFAULT_HOST;
  const port = options.port ?? DEFAULT_PORT;
  const projectRoot = path.resolve(options.projectRoot ?? defaultProjectRoot);
  const url = new URL(requestUrl, `http://${host}:${port}`);
  const relativePath = decodeURIComponent(url.pathname === "/" ? "/index.html" : url.pathname);

  if (relativePath.includes("\0")) {
    throw new Error("Invalid request path");
  }

  const filePath = path.resolve(projectRoot, `.${relativePath}`);

  if (isPathOutsideRoot(projectRoot, filePath)) {
    return null;
  }

  return filePath;
}

function isDirectRun() {
  return Boolean(process.argv[1] && path.resolve(process.argv[1]) === __filename);
}

/**
 * @param {string} projectRoot
 * @param {string} filePath
 * @returns {string | null}
 */
function resolveSafeFilePath(projectRoot, filePath) {
  const realProjectRoot = fs.realpathSync(projectRoot);

  try {
    const realFilePath = fs.realpathSync(filePath);
    return isPathOutsideRoot(realProjectRoot, realFilePath) ? null : realFilePath;
  } catch (error) {
    if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") {
      return filePath;
    }

    throw error;
  }
}

/**
 * @param {string} rootPath
 * @param {string} targetPath
 * @returns {boolean}
 */
function isPathOutsideRoot(rootPath, targetPath) {
  const relativeToRoot = path.relative(rootPath, targetPath);

  return (
    relativeToRoot === ".." ||
    relativeToRoot.startsWith(`..${path.sep}`) ||
    path.isAbsolute(relativeToRoot)
  );
}
