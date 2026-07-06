---
name: tmux-session
trigger: "session management, parallel work, multi-pane tasks, or persistent terminal sessions"
requires: [tmux]
---

# Tmux Session Management

## Overview

This skill manages tmux sessions for structured, persistent terminal work. Tmux
lets the agent run parallel processes (editor, server, tests, logs) in organized
panes, survive disconnections, and maintain named workspaces. Every long-running
project should have a tmux session — it's the agent's equivalent of a multi-monitor
desktop.

## Prerequisites

- [ ] `tmux` is installed — `paru -S tmux`
- [ ] Terminal supports 256 colors (most modern terminals do)
- [ ] Optional: custom `.tmux.conf` at `~/.tmux.conf`

**Verify setup:**
```bash
tmux -V  # Should show tmux 3.x+
```

---

## Procedure 1: Session Management

### Step 1: Create — Start a Named Session

Always use named sessions. Never use the default unnamed session.

```bash
# Create a new named session:
tmux new-session -d -s <session-name>

# Create with a specific starting directory:
tmux new-session -d -s <session-name> -c /path/to/project
```

**Session naming convention:**

| Pattern              | Use Case                       | Example                    |
|----------------------|--------------------------------|----------------------------|
| `project-name`      | Main session for a project     | `shellll`                  |
| `project-task`      | Focused task within project    | `shellll-debug`            |
| `agent-purpose`     | Agent-specific workspace       | `agent-gemini`             |
| `monitor`           | System monitoring session      | `monitor`                  |

**Rules:**
- Lowercase, hyphens only: `my-project` not `My_Project`
- Keep names short (under 15 chars) — they appear in the status bar
- One session per project, multiple windows per context

### Step 2: List — View Existing Sessions

```bash
# List all sessions:
tmux list-sessions
# Short form:
tmux ls
```

**Output format:**
```
shellll: 3 windows (created Tue Jul  1 15:00:00 2026)
monitor: 1 windows (created Tue Jul  1 14:30:00 2026)
```

### Step 3: Attach — Connect to a Session

```bash
# Attach to a named session:
tmux attach-session -t <session-name>
# Short form:
tmux a -t <session-name>

# Attach or create if it doesn't exist:
tmux new-session -A -s <session-name>
```

**If already attached elsewhere:** Use `-d` to detach other clients first:
```bash
tmux attach-session -d -t <session-name>
```

### Step 4: Detach — Leave Without Killing

From within tmux, press `Ctrl-b d` (prefix + d).

Or from outside:
```bash
tmux detach-client -t <session-name>
```

### Step 5: Kill — Destroy a Session

```bash
# Kill a specific session:
tmux kill-session -t <session-name>

# Kill all sessions except the current one:
tmux kill-session -a

# Kill the tmux server entirely (all sessions):
tmux kill-server
```

---

## Procedure 2: Window and Pane Management

### Creating Windows (Tabs)

```bash
# Create a new window in the current session:
tmux new-window -t <session-name>

# Create with a name:
tmux new-window -t <session-name> -n "logs"

# Create with a starting command:
tmux new-window -t <session-name> -n "server" "npm run dev"
```

### Splitting Panes

```bash
# Split horizontally (top/bottom):
tmux split-window -t <session-name> -v

# Split vertically (left/right):
tmux split-window -t <session-name> -h

# Split with a specific size (percentage):
tmux split-window -t <session-name> -v -p 30    # 30% height

# Split with a starting directory:
tmux split-window -t <session-name> -v -c /path/to/dir

# Split and run a command:
tmux split-window -t <session-name> -v "tail -f /var/log/syslog"
```

### Navigating Panes

From within tmux (prefix = `Ctrl-b`):

| Key               | Action                       |
|--------------------|------------------------------|
| `Ctrl-b ↑/↓/←/→` | Move between panes           |
| `Ctrl-b o`        | Cycle through panes          |
| `Ctrl-b z`        | Toggle zoom (fullscreen pane)|
| `Ctrl-b q`        | Show pane numbers            |
| `Ctrl-b q N`      | Jump to pane N               |
| `Ctrl-b x`        | Kill current pane            |
| `Ctrl-b !`        | Break pane into new window   |

### Resizing Panes

```bash
# Resize from command line:
tmux resize-pane -t <session-name> -D 10   # Down 10 lines
tmux resize-pane -t <session-name> -U 10   # Up 10 lines
tmux resize-pane -t <session-name> -L 10   # Left 10 columns
tmux resize-pane -t <session-name> -R 10   # Right 10 columns
```

From within tmux: `Ctrl-b Alt-↑/↓/←/→` (hold Alt and arrow keys).

---

## Procedure 3: Common Layouts

### Dev Layout — Editor + Terminal

Standard development setup: large editor on top, terminal on bottom.

```bash
SESSION="dev"
PROJECT_DIR="/home/dhanushsr/Downloads/mygit/SHELLLL"

# Create session with editor pane
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n "code"

# Split: 70% editor (top), 30% terminal (bottom)
tmux split-window -t "$SESSION:code" -v -p 30 -c "$PROJECT_DIR"

# Select the top pane (editor)
tmux select-pane -t "$SESSION:code.0"

# Attach
tmux attach-session -t "$SESSION"
```

```
┌─────────────────────────────┐
│                             │
│     Editor / Code (70%)     │
│                             │
├─────────────────────────────┤
│  Terminal / Commands (30%)  │
└─────────────────────────────┘
```

### Debug Layout — Code + Logs + REPL

For debugging sessions: code on left, logs top-right, REPL bottom-right.

```bash
SESSION="debug"
PROJECT_DIR="/home/dhanushsr/Downloads/mygit/SHELLLL"

# Create session with code pane
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n "debug"

# Split vertically: 60% code (left), 40% right
tmux split-window -t "$SESSION:debug" -h -p 40 -c "$PROJECT_DIR"

# Split right pane horizontally: 50% logs (top-right), 50% REPL (bottom-right)
tmux split-window -t "$SESSION:debug.1" -v -p 50 -c "$PROJECT_DIR"

# Select the code pane
tmux select-pane -t "$SESSION:debug.0"

tmux attach-session -t "$SESSION"
```

```
┌──────────────────┬──────────────┐
│                  │   Logs (20%) │
│  Code (60%)      ├──────────────┤
│                  │   REPL (20%) │
└──────────────────┴──────────────┘
```

### Monitor Layout — Multi-Pane Status Dashboard

For monitoring multiple processes or services:

```bash
SESSION="monitor"

tmux new-session -d -s "$SESSION" -n "status"

# Create 2x2 grid
tmux split-window -t "$SESSION:status" -v
tmux split-window -t "$SESSION:status.0" -h
tmux split-window -t "$SESSION:status.2" -h

# Send monitoring commands to each pane
tmux send-keys -t "$SESSION:status.0" "htop" C-m
tmux send-keys -t "$SESSION:status.1" "watch -n 2 'df -h'" C-m
tmux send-keys -t "$SESSION:status.2" "journalctl -f" C-m
tmux send-keys -t "$SESSION:status.3" "watch -n 5 'free -h'" C-m

tmux attach-session -t "$SESSION"
```

```
┌───────────────┬───────────────┐
│     htop      │   disk usage  │
├───────────────┼───────────────┤
│  system logs  │  memory watch │
└───────────────┴───────────────┘
```

### Full-Stack Dev Layout — Frontend + Backend + DB + Logs

For full-stack projects with multiple services:

```bash
SESSION="fullstack"
PROJECT_DIR="/home/dhanushsr/Downloads/mygit/SHELLLL"

# Window 1: Code
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n "code"
tmux split-window -t "$SESSION:code" -v -p 30 -c "$PROJECT_DIR"

# Window 2: Services
tmux new-window -t "$SESSION" -n "services" -c "$PROJECT_DIR"
tmux split-window -t "$SESSION:services" -v -c "$PROJECT_DIR"
tmux split-window -t "$SESSION:services.0" -h -c "$PROJECT_DIR"

# Send commands to service panes
tmux send-keys -t "$SESSION:services.0" "# Frontend: npm run dev" C-m
tmux send-keys -t "$SESSION:services.1" "# Backend: npm run server" C-m
tmux send-keys -t "$SESSION:services.2" "# Logs: tail -f logs/app.log" C-m

# Window 3: Git
tmux new-window -t "$SESSION" -n "git" -c "$PROJECT_DIR"

# Start on the code window
tmux select-window -t "$SESSION:code"
tmux attach-session -t "$SESSION"
```

---

## Procedure 4: Sending Commands to Panes

This is critical for agent use — you can control panes programmatically.

```bash
# Send a command to a specific pane:
tmux send-keys -t <session>:<window>.<pane> "command here" C-m

# C-m simulates pressing Enter
# Without C-m, the text is typed but not executed

# Examples:
tmux send-keys -t dev:code.1 "npm test" C-m
tmux send-keys -t dev:code.0 "vim src/index.ts" C-m

# Send Ctrl-C to stop a running process:
tmux send-keys -t dev:services.0 C-c

# Send multiple commands:
tmux send-keys -t dev:code.1 "cd src && npm test" C-m
```

### Capturing Pane Output

Read what's currently displayed in a pane:

```bash
# Capture visible content:
tmux capture-pane -t <session>:<window>.<pane> -p

# Capture with history (last 1000 lines):
tmux capture-pane -t <session>:<window>.<pane> -p -S -1000

# Save to file:
tmux capture-pane -t <session>:<window>.<pane> -p > /tmp/pane-output.txt
```

---

## Procedure 5: Session Persistence (Manual Save/Restore)

Since `tmux-resurrect` may not be installed, here's manual persistence:

### Save Session Layout

```bash
# Save current layout to a script:
save_tmux_session() {
    local session="$1"
    local outfile="${2:-tmux-restore-${session}.sh}"

    echo "#!/bin/bash" > "$outfile"
    echo "# Auto-generated tmux restore script for session: $session" >> "$outfile"
    echo "# Generated: $(date)" >> "$outfile"
    echo "" >> "$outfile"

    # Get the working directory of the first pane
    local start_dir
    start_dir=$(tmux display-message -t "$session:0.0" -p '#{pane_current_path}')
    echo "tmux new-session -d -s '$session' -c '$start_dir'" >> "$outfile"

    # Iterate windows
    tmux list-windows -t "$session" -F '#{window_index} #{window_name} #{window_layout}' | while read -r idx name layout; do
        if [ "$idx" -gt 0 ]; then
            echo "tmux new-window -t '$session' -n '$name'" >> "$outfile"
        else
            echo "tmux rename-window -t '$session:0' '$name'" >> "$outfile"
        fi
        # Apply saved layout
        echo "tmux select-layout -t '$session:$name' '$layout'" >> "$outfile"
    done

    echo "tmux attach-session -t '$session'" >> "$outfile"
    chmod +x "$outfile"
    echo "Saved to $outfile"
}
```

### Restore Session

```bash
# Simply run the saved script:
bash tmux-restore-shellll.sh
```

---

## Procedure 6: Useful tmux Configuration

Recommended `~/.tmux.conf` additions for agent-friendly sessions:

```bash
# Enable mouse support (useful for visual navigation)
set -g mouse on

# Start window/pane numbering at 1 (not 0)
set -g base-index 1
setw -g pane-base-index 1

# Increase scrollback buffer
set -g history-limit 50000

# Renumber windows when one is closed
set -g renumber-windows on

# Show more informative status bar
set -g status-left '[#S] '
set -g status-right '%H:%M %d-%b-%y'

# Faster key repeat
set -sg escape-time 0

# Use 256 colors
set -g default-terminal "screen-256color"

# Highlight active pane
set -g pane-active-border-style "fg=green"
```

---

## Quick Reference

```
SESSION MANAGEMENT
─────────────────────────────────────────
tmux new-session -d -s NAME          create
tmux ls                              list
tmux a -t NAME                       attach
Ctrl-b d                             detach
tmux kill-session -t NAME            kill

WINDOWS
─────────────────────────────────────────
tmux new-window -t S -n NAME         new window
Ctrl-b c                             new window (inside)
Ctrl-b ,                             rename window
Ctrl-b n / p                         next/prev window
Ctrl-b 0-9                           jump to window N

PANES
─────────────────────────────────────────
Ctrl-b %                             split vertical
Ctrl-b "                             split horizontal
Ctrl-b ↑↓←→                          navigate panes
Ctrl-b z                             zoom/unzoom pane
Ctrl-b x                             kill pane
Ctrl-b {  /  }                       swap pane left/right

SEND COMMANDS (AGENT KEY)
─────────────────────────────────────────
tmux send-keys -t S:W.P "cmd" C-m    send + execute
tmux send-keys -t S:W.P C-c          interrupt
tmux capture-pane -t S:W.P -p        read output
```

## Common Pitfalls

- ⚠️ **Don't forget `C-m` when sending commands** — Without it, the text is typed
  but not executed. Always append `C-m` (Enter) unless you intentionally want to
  stage text without running it.
- ⚠️ **Don't create unnamed sessions** — Always use `-s name`. Unnamed sessions
  get numbered (0, 1, 2) and become impossible to manage.
- ⚠️ **Don't nest tmux sessions** — If you're already inside tmux and try to create
  a new session, you'll get nested sessions. Use `tmux new-session -d` (detached)
  and then switch with `Ctrl-b s`.
- ⚠️ **Watch the pane numbering** — Panes renumber when you close one. Always verify
  pane indices with `tmux list-panes -t session:window` before sending commands.
- ⚠️ **Don't forget to detach before closing terminal** — If your terminal closes
  without detaching, the session survives but your client doesn't get a clean exit.
  Always `Ctrl-b d` first.
- ⚠️ **Escape special characters in send-keys** — Quotes, dollars, and backticks
  need escaping: `tmux send-keys -t s:w.p 'echo "hello"' C-m`

## Related Skills

- `git_workflow.md` — Run git commands in a dedicated tmux pane
- `debug_loop.md` — Use the debug layout for systematic debugging
