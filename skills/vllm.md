# Skill: vLLM Local Engine
# Trigger: "start vllm", "local llm", "vllm serve", "/vllm", local model inference
# File: skills/vllm.md

---

## Purpose

Run open-weight LLMs locally using [vLLM](https://github.com/vllm-project/vllm) —
a fast, memory-efficient inference engine with an OpenAI-compatible REST API.
Zero cloud, zero cost, zero data egress.

---

## Prerequisites

| Requirement     | Check                                      | Install                                    |
|-----------------|--------------------------------------------|--------------------------------------------|
| Python 3.10+    | `python3 --version`                        | `paru -S python`                           |
| CUDA 12+        | `nvidia-smi`                               | `paru -S cuda`                             |
| GPU VRAM        | `nvidia-smi --query-gpu=memory.free --format=csv` | — (need ≥6 GB for 7B, ≥16 GB for 13B+) |
| pip             | `pip --version`                            | bundled with Python                        |
| vllm package    | `python3 -c 'import vllm'`                | `pip install vllm` (see step 1)            |

---

## Step 1 — Install vLLM

```bash
# Create a dedicated venv to avoid conflicts (recommended)
python3 -m venv ~/.venvs/vllm
source ~/.venvs/vllm/bin/activate

# Install vLLM (CUDA 12.1 wheels, adjust CUDA version if needed)
pip install vllm

# Verify
python3 -c "import vllm; print(vllm.__version__)"
```

> **Tip**: If you hit CUDA version mismatches, install the matching wheel:
> ```bash
> pip install vllm --extra-index-url https://download.pytorch.org/whl/cu121
> ```

---

## Step 2 — Choose a Model

Common starting points (HuggingFace IDs):

| Model                          | VRAM  | Notes                           |
|-------------------------------|-------|---------------------------------|
| `Qwen/Qwen2.5-7B-Instruct`   | ~14 GB| Great all-rounder, fast         |
| `mistralai/Mistral-7B-Instruct-v0.3` | ~14 GB | Strong reasoning          |
| `meta-llama/Llama-3.1-8B-Instruct`  | ~16 GB | Needs HF token (gated)   |
| `Qwen/Qwen2.5-14B-Instruct`  | ~28 GB| Better quality, more VRAM       |
| `deepseek-ai/DeepSeek-R1-Distill-Qwen-7B` | ~14 GB | Strong coder  |

Set your choice in `.env` or `keys/`:
```bash
# .env
VLLM_MODEL=Qwen/Qwen2.5-7B-Instruct
```

---

## Step 3 — Start the Server

```bash
# Activate venv if using one
source ~/.venvs/vllm/bin/activate

# Start vLLM server (OpenAI-compatible REST API on port 8000)
vllm serve "${VLLM_MODEL:-Qwen/Qwen2.5-7B-Instruct}" \
  --host 0.0.0.0 \
  --port "${VLLM_PORT:-8000}" \
  --api-key "${VLLM_API_KEY:-not-needed}" \
  --dtype auto \
  --max-model-len 8192

# Or use the SHELLLL alias (after sourcing .agent_bashrc):
vllm-start
```

The server is ready when you see:
```
INFO:     Application startup complete.
```

---

## Step 4 — Health Check

```bash
# Quick health check
curl -s "${VLLM_BASE_URL:-http://localhost:8000}/health" && echo " OK"

# List available models
curl -s "${VLLM_BASE_URL:-http://localhost:8000}/v1/models" | jq '.data[].id'

# Test completion
curl -s "${VLLM_BASE_URL:-http://localhost:8000}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${VLLM_API_KEY:-not-needed}" \
  -d '{
    "model": "'"${VLLM_MODEL:-Qwen/Qwen2.5-7B-Instruct}"'",
    "messages": [{"role": "user", "content": "Hello, are you running?"}],
    "max_tokens": 64
  }' | jq '.choices[0].message.content'
```

---

## Step 5 — Wire to MCP

The `mcp/vllm.json` config uses `openai-mcp-server` as a bridge. Load it in:

| Agent Client | Config location           | How                                  |
|-------------|---------------------------|--------------------------------------|
| Gemini CLI  | `.gemini/settings.json`   | Add vllm block under `mcpServers`    |
| Claude      | `.claude/mcp.json`        | Merge `mcp/vllm.json` → mcpServers  |
| opencode    | `opencode.json`            | Add under `mcp.servers`             |

Example for `.gemini/settings.json`:
```json
{
  "mcpServers": {
    "vllm": {
      "command": "npx",
      "args": ["-y", "openai-mcp-server"],
      "env": {
        "OPENAI_API_KEY": "not-needed",
        "OPENAI_BASE_URL": "http://localhost:8000/v1",
        "OPENAI_MODEL": "Qwen/Qwen2.5-7B-Instruct"
      }
    }
  }
}
```

---

## Managing the Server

```bash
# Start in a detached tmux pane
vllm-start              # alias defined in .agent_bashrc

# Check if running
vllm-status             # alias defined in .agent_bashrc

# Stop the server
vllm-stop               # alias defined in .agent_bashrc

# Tail logs
tmux attach-session -t vllm-server
```

---

## Troubleshooting

| Symptom                            | Likely Cause                        | Fix                                      |
|------------------------------------|-------------------------------------|------------------------------------------|
| `CUDA out of memory`               | Model too large for VRAM            | Use smaller model or set `--max-model-len 4096` |
| `Connection refused` on port 8000  | Server not started                  | Run `vllm-start`                         |
| `401 Unauthorized`                 | API key mismatch                    | Ensure `VLLM_API_KEY` matches `--api-key` in server |
| Model not downloading              | HF_TOKEN not set (gated model)      | `_load_key HF_TOKEN hf_token` + token in keys/ |
| Slow first response                | Model loading into VRAM             | Wait — subsequent requests are fast       |
| `AttributeError: module 'vllm'`    | Version mismatch                    | `pip install --upgrade vllm`             |

---

## Quick Reference

```bash
# SHELLLL aliases (from .agent_bashrc)
vllm-start   # Start vLLM server in tmux session
vllm-stop    # Kill vLLM tmux session
vllm-status  # Check if server is healthy
vllm-models  # List loaded models
```

---

## Notes for Agents

- vLLM server must be started **before** the MCP client connects
- The OpenAI-compatible API means you can use it as a drop-in for any OpenAI SDK
- Model ID in API calls must exactly match the `--model` flag used at server start
- First request triggers model loading — expect 30–60s cold start
- Use `tmux` to keep server alive across agent sessions: `vllm-start` handles this

---

*Last updated: 2026-07-06*
*Maintainer: shellll-agent*
