import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";

import { createRequestHandler, resolveRequestPath } from "../../scripts/dev.mjs";

test("returns 400 for malformed request URLs instead of crashing the handler", () => {
  const projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), "spending-personality-dev-"));
  fs.writeFileSync(path.join(projectRoot, "index.html"), "<!doctype html>");

  const handler = createRequestHandler({ projectRoot, port: 4173 });
  const response = createMockResponse();

  assert.doesNotThrow(() => {
    handler({ method: "GET", url: "/%" }, response);
  });

  assert.equal(response.statusCode, 400);
  assert.equal(response.body, "Bad Request");
});

test("blocks sibling-directory traversal even when the directory names share a prefix", () => {
  const workspaceRoot = fs.mkdtempSync(path.join(os.tmpdir(), "spending-personality-root-"));
  const projectRoot = path.join(workspaceRoot, "Spending-Personality");
  const siblingRoot = path.join(workspaceRoot, "Spending-Personality2");

  fs.mkdirSync(projectRoot);
  fs.mkdirSync(siblingRoot);
  fs.writeFileSync(path.join(siblingRoot, "secret.txt"), "nope");

  const resolvedPath = resolveRequestPath("/%2e%2e%2fSpending-Personality2/secret.txt", {
    projectRoot,
    port: 4173
  });

  assert.equal(resolvedPath, null);
});

/**
 * @returns {{
 *   body: string,
 *   headers: Record<string, string>,
 *   statusCode: number | null,
 *   end: (body?: string) => void,
 *   writeHead: (statusCode: number, headers: Record<string, string>) => void
 * }}
 */
function createMockResponse() {
  return {
    body: "",
    headers: {},
    statusCode: null,
    writeHead(statusCode, headers) {
      this.statusCode = statusCode;
      this.headers = headers;
    },
    end(body = "") {
      this.body = body;
    }
  };
}
