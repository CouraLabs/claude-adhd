---
name: setup-statusline
title: Enable ADHD Plugin Statusline
description: Configure Claude Code to display comprehensive status information including context window, model, git info, and rate limits
difficulty: easy
---

# Enable ADHD Plugin Statusline

This skill enables the comprehensive statusline that displays:

- **Location**: Current directory, project, git branch with uncommitted changes indicator
- **Model & Session**: Model name/ID, effort level, thinking mode, agent, session details
- **Context Window**: Token usage (color-coded), input/output/cache tokens
- **Limits & Cache**: Rate limits with reset times, prompt cache state and performance metrics

## Setup

The statusline script is bundled in this plugin at `bin/statusline.sh`.

Run this command to enable it:

```bash
/statusline ${CLAUDE_PLUGIN_ROOT}/bin/statusline.sh
```

Your status line will immediately show all available information across up to 4 lines.

## Requirements

- `jq` (command-line JSON processor) — used to parse Claude Code session data

## Customization

To modify the statusline layout, colors, or fields, edit the script directly or contact support for custom configurations.

## Disable

To turn off the statusline:

```bash
/statusline
```

This returns the status line to the default minimal display.
