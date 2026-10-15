// Guard for the player-critic subagent. It runs as a PreToolUse hook declared in
// .claude/agents/player-critic.md, so it only fires while that subagent is active, and it blocks
// any tool call that reaches outside review/inbox. It FAILS CLOSED: any internal error blocks.
// Paths resolve against the repo root (found from this file's own location, two folders up), not
// the working directory, so it behaves the same whatever folder the session runs in.
// Exit code 2 blocks the call and sends stderr back to the critic.
// INSTALL: copy to .claude/hooks/critic_guard.mjs (see HANDOFF.md step 0), then deny edits to it.
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..");
const INBOX = norm(path.join(ROOT, "review", "inbox"));

process.on("uncaughtException", (e) => block("Guard error, blocked for safety: " + e.message));

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    block("Guard could not parse the tool call, blocked for safety.");
  }
  const tool = String(input.tool_name || "");
  const ti = input.tool_input || {};
  if (tool === "SubagentHandback") allow();

  const inside = (p) => {
    if (!p) return false;
    const abs = norm(path.resolve(ROOT, String(p)));
    return abs === INBOX || abs.startsWith(INBOX + "/");
  };

  if (tool === "Read") {
    if (inside(ti.file_path)) allow();
    block(`Blocked: you can only look at files inside review/inbox/. (${ti.file_path})`);
  }
  if (tool === "Glob") {
    const pattern = String(ti.pattern || "");
    if (pattern.includes("..")) block("Blocked: stay inside review/inbox/.");
    if (ti.path) {
      // An absolute pattern would ignore the search folder, so it must also point inside the inbox.
      if (path.isAbsolute(pattern) || /^[a-zA-Z]:/.test(pattern) || pattern.startsWith("/") || pattern.startsWith("\\"))
        block("Blocked: use a relative pattern inside review/inbox/.");
      if (inside(ti.path)) allow();
      block("Blocked: you can only search inside review/inbox/.");
    }
    if (path.isAbsolute(pattern) ? inside(pattern.split("*")[0]) : norm(pattern).startsWith("review/inbox/")) allow();
    block("Blocked: you can only search inside review/inbox/. Use a pattern like review/inbox/**/*");
  }
  block(`Blocked: the ${tool} tool is not available to you. Use Read and Glob on review/inbox/ only.`);
});

function norm(p) {
  let s = String(p).replace(/\\/g, "/");
  if (process.platform === "win32") s = s.toLowerCase();
  return s.replace(/\/+$/, "");
}
function allow() {
  process.exit(0);
}
function block(msg) {
  process.stderr.write(msg + "\n");
  process.exit(2);
}
