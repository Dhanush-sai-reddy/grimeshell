# MCP Server Configuration

This directory contains Model Context Protocol (MCP) server configurations
used by AI agents in the SHELLLL brain.

## What is MCP?

MCP (Model Context Protocol) allows AI agents to interact with external tools
and services through a standardized interface. Each MCP server provides a set
of capabilities (tools) that agents can invoke.

## Current Servers

### bash-mcp (`bash-mcp.json`)

Provides shell command execution with a security allowlist.

**Allowed Commands:**
- File ops: `ls`, `cat`, `grep`, `find`, `head`, `tail`, `wc`, `sort`, `uniq`, `sed`, `awk`
- Git: `git`, `gh`
- Dev tools: `node`, `npm`, `npx`, `python3`, `pip`, `shellcheck`, `ruff`
- System: `tmux`, `curl`, `paru`, `lsd`, `fzf`, `jq`

**Security:** Only allowlisted commands can be executed. No `rm`, `sudo`, `chmod`,
or other destructive commands are permitted by default.

## Adding a New MCP Server

1. Create a new JSON file in this directory (e.g., `my-server.json`)
2. Follow this structure:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "package-name"],
      "env": {
        "API_KEY": "${API_KEY}"
      }
    }
  }
}
```

3. Reference it in your agent's configuration:
   - For Gemini: Add to `.gemini/settings.json`
   - For Claude: Add to `.claude/mcp.json`
   - For opencode: Add to `opencode.json`

4. Test the server with `--dry-run` before live use

## Environment Variables

Sensitive values (API keys, tokens) should use environment variable references
(`${VAR_NAME}`) rather than hardcoded values. Set them in `.agent_bashrc` or
your shell profile.

## Troubleshooting

- **Server won't start**: Check that the package is installed (`npx -y <package>`)
- **Command blocked**: Add it to `allowedCommands` in the server config
- **Timeout**: Some MCP servers need a moment to initialize; check logs
- **Port conflict**: If running multiple servers, ensure unique ports
