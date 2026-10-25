#!/usr/bin/env python3
"""PreToolUse guard for pipeline subagents.

Usage (from a subagent's frontmatter hook): worktree_guard.py <agent-name>

Denies a write tool call unless the target file
  1. lies inside a worktree registered for this agent, and
  2. is a path this agent owns (see ALLOWED), and
  3. is not a protected path (git data, .claude/, CLAUDE.md).
Denies mutating git commands from Bash (agents never run git; the orchestrator does).

Registry: <project>/.claude/worktrees/.guard/<agent>.roots, one absolute worktree
path per line, written by the orchestrator when it creates a stage worktree and
removed when it deletes it. No registry or no matching root means deny (fail closed).
Bash redirects and scripts are not path-checked; the orchestrator's post-stage
scope check still applies.
"""
import json
import os
import re
import shlex
import sys

AGENT = sys.argv[1] if len(sys.argv) > 1 else ""

# Paths relative to the worktree root that each agent may write.
# None for forge-dev: any code path except docs/ (docs/engineering/ only).
ALLOWED = {
    "scribe-requirements": [r"^docs/product/"],
    "canvas-ui": [r"^docs/design/"],
    "atlas-architect": [r"^docs/system/", r"^docs/decisions/"],
    # QA code lives in a separate qa/ folder per component so it never collides
    # with the developer's unit tests (forge-dev may not write qa/).
    "probe-qa": [r"^docs/test/", r"(^|/)qa/"],
    "forge-dev": None,
}
PROTECTED = [r"^\.git(/|$)", r"^\.claude/", r"^CLAUDE\.md$"]
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
READONLY_GIT = {
    "status", "diff", "log", "show", "rev-parse", "ls-files", "grep",
    "blame", "describe", "rev-list", "shortlog", "cat-file",
}


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def project_dir():
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return env
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def registered_roots():
    path = os.path.join(project_dir(), ".claude", "worktrees", ".guard", AGENT + ".roots")
    try:
        with open(path) as f:
            lines = [line.strip() for line in f if line.strip()]
    except OSError:
        return []
    return [os.path.realpath(p) for p in lines]


def check_write(tool_input):
    target = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not target:
        deny("Guard: write call without a file path is not allowed.")
    target = os.path.realpath(target)
    roots = registered_roots()
    if not roots:
        deny("Guard: no worktree is registered for agent '%s'. The orchestrator must "
             "register your worktree before you write." % AGENT)
    for root in roots:
        if target == root or target.startswith(root + os.sep):
            rel = os.path.relpath(target, root)
            break
    else:
        deny("Guard: '%s' is outside your worktree(s): %s. Write only inside your "
             "assigned worktree." % (target, ", ".join(roots)))
    for pattern in PROTECTED:
        if re.search(pattern, rel):
            deny("Guard: '%s' is protected (git data, .claude/, CLAUDE.md)." % rel)
    allowed = ALLOWED.get(AGENT, [])
    if AGENT == "forge-dev":
        if rel.startswith("docs/") and not rel.startswith("docs/engineering/"):
            deny("Guard: forge-dev may write docs only under docs/engineering/. "
                 "Report other document changes to the orchestrator.")
        if re.search(r"(^|/)qa/", rel):
            deny("Guard: qa/ folders belong to probe-qa; put unit tests in the component's own test target.")
        return
    if not any(re.search(p, rel) for p in allowed):
        deny("Guard: agent '%s' may not write '%s'. Allowed: %s" % (AGENT, rel, ", ".join(allowed) or "none"))


def git_subcommand(tokens):
    """Return the git subcommand following 'git' in a token list, skipping global options."""
    i = tokens.index("git") + 1
    while i < len(tokens):
        t = tokens[i]
        if t in ("-C", "-c", "--git-dir", "--work-tree", "--namespace"):
            i += 2
        elif t.startswith("-"):
            i += 1
        else:
            return t
    return ""


def check_bash(tool_input):
    command = tool_input.get("command", "")
    for segment in re.split(r";|&&|\|\||\||\n", command):
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        if "git" in tokens:
            sub = git_subcommand(tokens)
            if sub not in READONLY_GIT:
                deny("Guard: git '%s' is not allowed for agents. Only read-only git "
                     "(status, diff, log, show...) is permitted; the orchestrator commits." % (sub or "?"))


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        deny("Guard: could not read hook input.")
    tool = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}
    if tool in WRITE_TOOLS:
        check_write(tool_input)
    elif tool == "Bash":
        check_bash(tool_input)
    sys.exit(0)


if __name__ == "__main__":
    main()
