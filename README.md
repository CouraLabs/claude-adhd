# coura-labs — Claude Code ADHD Plugin

A Claude Code plugin that makes sessions easier to follow for people with ADHD: short, action-first responses, an informative status line, color themes, and faster Explore subagents.

## Features

### ADHD output style
`output-styles/adhd.md`

- Leads with the answer or the next action — no preamble
- Short, scannable bullets; bold only for what matters most
- Multi-step work as numbered checklists, ending with **Next:**
- Unrelated ideas go under **Parked for later** instead of derailing the task
- Recommends one option instead of long lists
- Warm, direct, non-judgmental tone

Enable with `/output-style coura-labs:ADHD`.

### Status line
`bin/statusline.sh` — two lines:

1. **Model ∙ effort ∙ context ∙ cache ∙ cost/tokens**
   - Model name with per-family color and icon (Fable, Opus, Sonnet, Haiku)
   - Effort level gauge (`low` → `max`)
   - Context window usage, colored on a blue → red gradient
   - Prompt cache state (warm/cold) and hit ratio
   - Session cost and total tokens (main transcript + subagents)
2. **Folder ∙ git ∙ 5h gauge ∙ 7d gauge**
   - Project folder and git branch with added/removed line counts
   - 5-hour and 7-day rate limit gauges with time until reset

### Subagent status line
`bin/subagent-statusline.sh` — one row per running subagent: name, description, model, effort, and tokens vs. context window.

### Setup skill
`skills/setup-statusline.md` — walks Claude through enabling the status line.

### Explore agent tuning
`hooks/register.ts` — the built-in **Explore** subagent runs on **Haiku with high effort** instead of inheriting the parent model. Forks and workflow agents are left untouched, and if the hook fails the agent spawns unchanged.

### Themes
`themes/` — 12 color themes:

| Dark | Light |
|------|-------|
| Catppuccin Mocha | Catppuccin Latte |
| Dracula | Rosé Pine Dawn |
| Everforest | Solarized Light |
| Gruvbox Dark | |
| Kanagawa | |
| Nord | |
| Rosé Pine | |
| Rosé Pine Moon | |
| Tokyo Night | |

## Requirements

- Claude Code
- `jq` (used by the status line scripts)
- `git` (optional, for branch info)

## Setup

1. Install the plugin in Claude Code.
2. Turn on the output style: `/output-style coura-labs:ADHD`
3. Turn on the status line: `/statusline ${CLAUDE_PLUGIN_ROOT}/bin/statusline.sh` (or ask Claude to run the `setup-statusline` skill)

## Layout

```
.claude-plugin/   plugin manifest + TypeScript types for hooks
bin/              status line scripts
hooks/            hook registration (Explore agent tuning)
output-styles/    ADHD output style
skills/           setup-statusline skill
themes/           color themes
```

## Author

Rodrigo Coura
