#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = parseArgs(process.argv.slice(2));
const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), "..");

await main();

async function main() {
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

  const desiredSettings = getDesiredSettings(serviceDir);
  await syncProjectSettings({ projectName, scope, desiredSettings });

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
  ensureRepoRootLink(projectJson);

  console.log("");
  console.log("Bootstrap complete.");
  console.log(`Service directory: ${path.relative(repoRoot, serviceDir)}`);
  console.log(`Scope: ${scope}`);
  console.log(`Project name: ${projectName}`);
  console.log(`Linked project id: ${projectJson.projectId}`);
  console.log(`Linked org id: ${projectJson.orgId}`);
  console.log(`Root directory: ${desiredSettings.rootDirectory}`);

  if (desiredSettings.buildCommand) {
    console.log(`Build command: ${desiredSettings.buildCommand}`);
  }

  if (desiredSettings.outputDirectory) {
    console.log(`Output directory: ${desiredSettings.outputDirectory}`);
  }

  console.log(`Production deploy cwd: ${path.relative(repoRoot, repoRoot) || "."}`);
}

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

function getDesiredSettings(serviceDir) {
  const relativeServiceDir = path.relative(repoRoot, serviceDir).split(path.sep).join("/");
  const desiredSettings = {
    rootDirectory: relativeServiceDir,
  };

  const packageJsonPath = path.join(serviceDir, "package.json");

  if (fs.existsSync(packageJsonPath)) {
    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));

    if (packageJson.scripts?.build) {
      desiredSettings.buildCommand = "npm run build";
    }
  }

  const vercelJsonPath = path.join(serviceDir, "vercel.json");

  if (fs.existsSync(vercelJsonPath)) {
    const vercelJson = JSON.parse(fs.readFileSync(vercelJsonPath, "utf8"));

    if (typeof vercelJson.outputDirectory === "string" && vercelJson.outputDirectory) {
      desiredSettings.outputDirectory = vercelJson.outputDirectory;
    }
  }

  return desiredSettings;
}

async function syncProjectSettings({ projectName, scope, desiredSettings }) {
  const authToken = readVercelToken();
  const currentProject = await requestVercelProject({
    authToken,
    projectName,
    scope,
    method: "GET",
  });

  const updates = Object.fromEntries(
    Object.entries(desiredSettings).filter(([key, value]) => currentProject[key] !== value),
  );

  if (Object.keys(updates).length === 0) {
    log("Project settings already match the service directory.");
    return;
  }

  const updatedProject = await requestVercelProject({
    authToken,
    projectName,
    scope,
    method: "PATCH",
    body: updates,
  });

  for (const [key, value] of Object.entries(updates)) {
    if (updatedProject[key] !== value) {
      fail(`Failed to persist project setting ${key}=${value}`);
    }
  }

  log(`Updated project settings: ${Object.keys(updates).join(", ")}`);
}

async function requestVercelProject({ authToken, projectName, scope, method, body }) {
  const query = new URLSearchParams({ slug: scope });
  const response = await fetch(
    `https://api.vercel.com/v9/projects/${encodeURIComponent(projectName)}?${query.toString()}`,
    {
      method,
      headers: {
        Authorization: `Bearer ${authToken}`,
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
    },
  );

  const payload = await response.json();

  if (!response.ok) {
    fail(payload.error?.message ?? `Vercel API request failed with status ${response.status}`);
  }

  return payload;
}

function readVercelToken() {
  if (process.env.VERCEL_TOKEN) {
    return process.env.VERCEL_TOKEN;
  }

  const authPaths = [
    path.join(process.env.HOME ?? "", ".vercel", "auth.json"),
    path.join(process.env.HOME ?? "", "Library/Application Support/com.vercel.cli/auth.json"),
  ];

  for (const authPath of authPaths) {
    if (!authPath || !fs.existsSync(authPath)) {
      continue;
    }

    const authJson = JSON.parse(fs.readFileSync(authPath, "utf8"));

    if (typeof authJson.token === "string" && authJson.token) {
      return authJson.token;
    }
  }

  fail("Could not find a Vercel API token. Set VERCEL_TOKEN or log in with the Vercel CLI.");
}

function ensureRepoRootLink(projectJson) {
  const rootProjectJsonPath = path.join(repoRoot, ".vercel", "project.json");
  const rootVercelDir = path.dirname(rootProjectJsonPath);

  if (fs.existsSync(rootProjectJsonPath)) {
    const currentRootLink = JSON.parse(fs.readFileSync(rootProjectJsonPath, "utf8"));

    if (
      currentRootLink.projectId !== projectJson.projectId ||
      currentRootLink.orgId !== projectJson.orgId
    ) {
      log(
        "Skipped repo-root .vercel/project.json update because it is linked to a different project.",
      );
      return;
    }
  }

  fs.mkdirSync(rootVercelDir, { recursive: true });
  fs.writeFileSync(rootProjectJsonPath, `${JSON.stringify(projectJson, null, 2)}\n`);
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
