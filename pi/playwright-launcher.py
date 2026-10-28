"""Run the active Claude Playwright MCP definition without copying it into Pi config."""

import json
import os
from pathlib import Path

CONFIG = Path.home() / ".pi/agent/claude-plugins/playwright/.mcp.json"


def main() -> None:
    try:
        with CONFIG.open(encoding="utf-8") as stream:
            servers = json.load(stream)
    except (OSError, json.JSONDecodeError):
        raise SystemExit(
            f"Cannot read Claude Playwright MCP definition: {CONFIG}"
        ) from None
    definition = servers.get("playwright") if isinstance(servers, dict) else None
    if not isinstance(definition, dict):
        raise SystemExit(
            f"Claude Playwright MCP definition missing or invalid: {CONFIG}"
        )

    command = definition.get("command")
    args = definition.get("args", [])
    env = definition.get("env", {})
    cwd = definition.get("cwd")
    if not isinstance(command, str) or not command:
        raise SystemExit(f"Claude Playwright MCP command missing or invalid: {CONFIG}")
    if not isinstance(args, list) or not all(isinstance(arg, str) for arg in args):
        raise SystemExit(f"Claude Playwright MCP args must be strings: {CONFIG}")
    if not isinstance(env, dict) or not all(
        isinstance(k, str) and isinstance(v, str) for k, v in env.items()
    ):
        raise SystemExit(f"Claude Playwright MCP env must contain strings: {CONFIG}")
    if cwd is not None and not isinstance(cwd, str):
        raise SystemExit(f"Claude Playwright MCP cwd must be a string: {CONFIG}")

    child_env = os.environ.copy()
    child_env.update(env)
    if cwd is not None:
        os.chdir(cwd)
    # Execute the explicitly trusted MCP argv directly; do not route config through a shell.
    os.execvpe(command, [command, *args], child_env)


if __name__ == "__main__":
    main()
