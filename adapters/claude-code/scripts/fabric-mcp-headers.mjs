/**
 * Fabric MCP header helper for Claude Code.
 *
 * Prints a JSON object of HTTP headers to stdout, which Claude Code merges into the
 * request headers for the Fabric Core MCP server.
 *
 * It mints a Microsoft Entra ID access token by shelling out to the Azure CLI. It makes
 * no network calls itself and never touches a Fabric API. Nothing is cached, so the
 * helper is safe to re-run on every connect and after a 401/403.
 *
 * Requirements:
 *   - azure CLI on PATH, signed in:  az login --allow-no-subscriptions
 *   - Node.js 22 or later
 *
 * Claude Code gives a headersHelper 10 seconds. The Azure CLI normally answers in about
 * one second, so the internal timeout is deliberately shorter than the host limit.
 */

import { execSync } from "node:child_process";

const RESOURCE = process.env.FABRIC_MCP_RESOURCE ?? "https://api.fabric.microsoft.com";
const TIMEOUT_MS = 8000;

function fail(message) {
  process.stderr.write(`fabric-mcp-headers: ${message}\n`);
  process.exit(1);
}

let token;
try {
  token = execSync(
    `az account get-access-token --resource ${RESOURCE} --query accessToken -o tsv`,
    { encoding: "utf8", timeout: TIMEOUT_MS, stdio: ["ignore", "pipe", "pipe"] },
  ).trim();
} catch (error) {
  fail(
    "could not get a token from the Azure CLI. " +
      "Run 'az login --allow-no-subscriptions' in the same environment, then reconnect the server. " +
      `(${error.message.split("\n")[0]})`,
  );
}

if (!token) {
  fail("the Azure CLI returned an empty token. Check 'az account show' for the signed-in tenant.");
}

process.stdout.write(JSON.stringify({ Authorization: `Bearer ${token}` }));
