# MCP Server Configuration

This directory contains Model Context Protocol (MCP) server configurations
used by AI agents in the SHELLLL brain.

Only **JSON reference configs** live here — no actual binaries, venvs, or
installed packages. See `.gitignore` for what is excluded.

## What is MCP?

MCP (Model Context Protocol) allows AI agents to interact with external tools
and services through a standardized interface. Each MCP server provides a set
of capabilities (tools) that agents can invoke.

---

## Servers

### 1. `bash-mcp.json` — Shell Command Execution
Local stdio MCP server providing shell command execution with a security allowlist.

- **Type**: `stdio` / `npx`
- **Command**: `npx -y bash-mcp`
- **Allowed**: `ls`, `cat`, `grep`, `find`, `git`, `gh`, `tmux`, `node`, `npm`, `npx`, `python3`, `curl`, `fzf`, `jq`, `paru`, `lsd`

---

### 2. `lfm2-inbrowser.json` — LFM2 In-Browser Tool Calling
LiquidAI LFM2 running entirely in-browser via WebGPU + Transformers.js.
Zero cloud dependency — runs on consumer hardware.

- **Type**: `sse`
- **URL**: `https://liquidai-lfm2-mcp.hf.space/gradio_api/mcp/sse`
- **Tags**: in-browser, webgpu, edge-llm, tool-calling

---

### 3. `unlimited-ocr.json` — Unlimited OCR
Baidu Unlimited-OCR — 32K context, one-shot multi-page PDF/document OCR. MIT license.

- **Type**: `sse`
- **URL**: `https://baidu-unlimited-ocr.hf.space/gradio_api/mcp/sse`
- **Model**: `baidu/Unlimited-OCR`
- **Tags**: ocr, pdf, document-parsing

---

### 4. `websearch.json` — Web Search
Real-time web search, news, and content extraction for agents.
Includes both SSE (HF-hosted) and local Brave Search options.

- **Type**: `sse` or `stdio`
- **SSE URL**: `https://huggingface-projects-websearch-mcp-server.hf.space/gradio_api/mcp/sse`
- **Local alt**: `npx -y @modelcontextprotocol/server-brave-search` (needs `BRAVE_API_KEY`)
- **Env**: `BRAVE_API_KEY` (optional, for local mode)

---

### 5. `huggingface.json` — HuggingFace Official MCP
Official HF MCP server — search models, datasets, papers, spaces on the Hub.
Also lets you call any Gradio-powered HF Space as an MCP tool.

- **Type**: `stdio` / `npx`
- **Command**: `npx -y @huggingface/mcp-server`
- **Env**: `HF_TOKEN` → load from `keys/hf_token`
- **Tags**: hub, models, datasets, papers, spaces

---

### 6. `cite-before-act.json` — Cite-Before-Act ⭐ Best Overall
**Award: Best Overall — MCP's 1st Birthday Hackathon**

Security middleware that intercepts any state-mutating tool call and requires
human approval before execution. Supports OS dialogs, Slack, Teams, Webex, CLI.

- **Type**: `sse`
- **URL**: `https://mcp-1st-birthday-cite-before-act.hf.space/gradio_api/mcp/sse`
- **Tags**: security, human-in-the-loop, approval, safety

---

### 7. `consilium.json` — Consilium Council
Multi-AI expert consensus platform. Multiple LLMs deliberate in a boardroom-style
session, debate queries using the BFT-derived Consilium Protocol, and reach
consensus via majority vote or ranked choice.

- **Type**: `sse`
- **URL**: `https://agents-mcp-hackathon-consilium-mcp.hf.space/gradio_api/mcp/sse`
- **Tags**: multi-agent, consensus, deliberation, council

---

### 8. `voicekit.json` — VoiceKit Audio Analysis
Audio analysis MCP server from MCP's 1st Birthday hackathon.
Tools: transcribe speech, isolate voices, compare speaker embeddings, extract acoustic features.

- **Type**: `sse`
- **URL**: `https://mcp-1st-birthday-voicekit.hf.space/gradio_api/mcp/sse`
- **Tags**: audio, voice, transcription, speaker-isolation

---

### 9. `kgb-mcp.json` — KGB Knowledge Graph Builder
Transforms raw text or web URLs into structured knowledge graphs using local LLMs.
Supports 300MB+ content, Neo4j/Qdrant persistence, and SVG visualization.

- **Type**: `sse`
- **URL**: `https://agents-mcp-hackathon-kgb-mcp.hf.space/gradio_api/mcp/sse`
- **Env**: `NEO4J_*`, `QDRANT_*` (optional, for persistence)
- **Tags**: knowledge-graph, neo4j, qdrant, RAG, visualization

---

### 10. `html2json.json` — HTML → JSON Structured Extraction
Converts structured HTML into clean JSON for AI agent consumption.
Strips boilerplate, extracts semantic structure for RAG and data pipelines.

- **Type**: `sse`
- **URL**: `https://garage-lab-mcp-html2json.hf.space/gradio_api/mcp/sse`
- **Tags**: html, json, scraping, structured-data, RAG

---

## Authentication

HF-hosted SSE servers may require `HF_TOKEN` in your environment.
Set it once:
```bash
echo 'hf_your_token' > "$SHELLLL_ROOT/keys/hf_token"
chmod 600 "$SHELLLL_ROOT/keys/hf_token"
source "$SHELLLL_ROOT/.agent_bashrc"   # auto-loads HF_TOKEN
```

For agent clients that need it in the URL header:
```
Authorization: Bearer ${HF_TOKEN}
```

## Adding a New MCP Server

1. Create a new JSON file in this directory (e.g., `my-server.json`)
2. Follow this structure:

```json
{
  "_info": {
    "name": "My Server",
    "source": "https://...",
    "type": "sse | stdio",
    "description": "What it does"
  },
  "mcpServers": {
    "server-name": {
      "type": "sse",
      "url": "https://space-name.hf.space/gradio_api/mcp/sse"
    }
  }
}
```

3. Reference it in your agent config:
   - **Gemini**: `.gemini/settings.json`
   - **Claude**: `.claude/mcp.json`
   - **opencode**: `opencode.json`

## Troubleshooting

- **SSE server not responding**: HF Spaces sleep after inactivity — hit the Space URL in a browser to wake it first
- **401 Unauthorized**: Set `HF_TOKEN` via `keys/hf_token` and re-source `.agent_bashrc`
- **npx server won't start**: Run `npx -y <package> --help` to verify it's resolvable
- **Port conflict**: If running multiple stdio servers, ensure unique ports
