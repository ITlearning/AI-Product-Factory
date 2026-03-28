#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = parseArgs(process.argv.slice(2));
const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), "..");

if (!args.serviceDir) {
  fail("Missing required --service-dir <path> argument.");
}

const serviceDir = path.resolve(repoRoot, args.serviceDir);

if (!fs.existsSync(serviceDir) || !fs.statSync(serviceDir).isDirectory()) {
  fail(`Service directory not found: ${serviceDir}`);
}

const projectName = args.projectName ?? slugify(path.basename(serviceDir));
const scope = args.scope ?? detectDefaultScope();

ensureVercelAuth();

if (projectExists(projectName, scope)) {
  log(`Project already exists: ${projectName} (${scope})`);
} else {
  runVercel(["project", "add", projectName, "--scope", scope], {
    cwd: repoRoot,
    stdio: "inherit",
  });
}

runVercel(["link", "--yes", "--scope", scope, "--project", projectName], {
  cwd: serviceDir,
  stdio: "inherit",
});

runVercel(["pull", "--yes", "--environment", "development", "--scope", scope], {
  cwd: serviceDir,
  stdio: "inherit",
});

const projectJsonPath = path.join(serviceDir, ".vercel", "project.json");

if (!fs.existsSync(projectJsonPath)) {
  fail(`Expected Vercel metadata at ${projectJsonPath}`);
}

const projectJson = JSON.parse(fs.readFileSync(projectJsonPath, "utf8"));

console.log("");
console.log("Bootstrap complete.");
console.log(`Service directory: ${path.relative(repoRoot, serviceDir)}`);
console.log(`Scope: ${scope}`);
console.log(`Project name: ${projectName}`);
console.log(`Linked project id: ${projectJson.projectId}`);
console.log(`Linked org id: ${projectJson.orgId}`);

function ensureVercelAuth() {
  runVercel(["whoami", "--no-color"], { cwd: repoRoot, stdio: "pipe" });
}

function detectDefaultScope() {
  if (process.env.VERCEL_SCOPE) {
    return process.env.VERCEL_SCOPE;
  }

  const teamsOutput = runVercel(["teams", "ls", "--no-color"], {
    cwd: repoRoot,
    stdio: "pipe",
  });

  const teamScopes = parseTeamScopes(teamsOutput);

  if (teamScopes.length === 1) {
    return teamScopes[0];
  }

  if (teamScopes.length > 1) {
    fail(
      `Multiple Vercel team scopes detected (${teamScopes.join(", ")}). Pass --scope explicitly.`,
    );
  }

  const whoamiOutput = runVercel(["whoami", "--no-color"], {
    cwd: repoRoot,
    stdio: "pipe",
  });

  const personalScope = whoamiOutput.trim();

  if (!personalScope) {
    fail("Could not determine a Vercel scope. Pass --scope explicitly.");
  }

  return personalScope;
}

function projectExists(projectName, scope) {
  try {
    execFileSync("vercel", ["project", "inspect", projectName, "--scope", scope, "--no-color"], {
      cwd: repoRoot,
      stdio: "pipe",
      encoding: "utf8",
    });
    return true;
  } catch {
    return false;
  }
}

function parseTeamScopes(output) {
  return stripAnsi(output)
    .split(/\r?\n/)
    .map((line) => line.trimEnd())
    .filter((line) => line.trim())
    .filter((line) => !line.startsWith("Fetching"))
    .filter((line) => !line.startsWith(">"))
    .filter((line) => !line.includes("Team name"))
    .map((line) => line.trim())
    .map((line) => line.match(/^(\S+)\s{2,}/)?.[1] ?? null)
    .filter(Boolean);
}

function parseArgs(argv) {
  const parsed = {};

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    const next = argv[index + 1];

    switch (token) {
      case "--service-dir":
        if (!next) {
          fail("Missing value for --service-dir");
        }
        parsed.serviceDir = next;
        index += 1;
        break;
      case "--project-name":
        if (!next) {
          fail("Missing value for --project-name");
        }
        parsed.projectName = next;
        index += 1;
        break;
      case "--scope":
        if (!next) {
          fail("Missing value for --scope");
        }
        parsed.scope = next;
        index += 1;
        break;
      default:
        fail(`Unknown argument: ${token}`);
    }
  }

  return parsed;
}

function runVercel(args, options) {
  try {
    return execFileSync("vercel", args, {
      cwd: options.cwd,
      stdio: options.stdio,
      encoding: options.stdio === "pipe" ? "utf8" : undefined,
    });
  } catch (error) {
    const detail = [error.stdout, error.stderr]
      .filter(Boolean)
      .map((value) => value.toString("utf8").trim())
      .filter(Boolean)
      .join("\n");

    fail(detail || error.message);
  }
}

function slugify(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function stripAnsi(value) {
  return value.replace(/\u001B\[[0-?]*[ -/]*[@-~]/g, "");
}

function log(message) {
  console.log(message);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
