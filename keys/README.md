# keys/

This folder holds API key files that are **never committed to git**.

Everything inside `keys/` is gitignored except this `README.md`.

## Usage

Place your keys as plain text files here:

```
keys/
├── hf_token          ← HuggingFace token (hf_...)
├── gemini_api_key    ← Gemini / Google AI Studio key
├── brave_api_key     ← Brave Search API key (optional, for websearch MCP)
├── tavily_api_key    ← Tavily API key (optional, for websearch MCP)
├── neo4j_password    ← Neo4j password (optional, for KGB-MCP)
└── qdrant_api_key    ← Qdrant API key (optional, for KGB-MCP)
```

## Loading keys in `.agent_bashrc`

The `.agent_bashrc` auto-loads this folder if it exists:

```bash
# Loads a key from keys/ file into an env var
load_key() {
    local var="$1"
    local file="$SHELLLL_ROOT/keys/$2"
    if [[ -f "$file" ]]; then
        export "$var"="$(cat "$file" | tr -d '[:space:]')"
    fi
}

load_key HF_TOKEN          hf_token
load_key HUGGINGFACE_TOKEN hf_token
load_key HF_API_TOKEN      hf_token
load_key GEMINI_API_KEY    gemini_api_key
load_key BRAVE_API_KEY     brave_api_key
load_key TAVILY_API_KEY    tavily_api_key
```

## Security

- Files are plain text, one key per file, no trailing newline needed
- `keys/*` is gitignored — these **will never be committed**
- `chmod 600 keys/*` is recommended after placing files

## Getting a HuggingFace Token

1. Go to https://huggingface.co/settings/tokens
2. Click **New token** → choose **Read** (or **Write** if you need to push)
3. Copy the `hf_...` token
4. `echo 'hf_yourtoken' > keys/hf_token`
5. `chmod 600 keys/hf_token`
