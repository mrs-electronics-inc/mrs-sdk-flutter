---
name: handoff
description: "Extracts relevant context from the current thread to start a new thread. Use when user wants to pivot to a new thread while preserving important context."
---

# Handoff

Transitions to a new thread by extracting what matters from the current thread.

## Guidelines

### Always Do (no asking)

- Ask the user for their goal for the new thread
- Extract files, decisions, and context relevant to that goal
- Generate a draft prompt that summarizes relevant context and outlines the new thread
- List all files that may be relevant to the new thread
- After user approval, copy the prompt to clipboard automatically

### Ask First (pause for approval)

- Present the draft prompt for user review before starting the new thread
- Confirm which files to include

### Never Do (hard stop)

- Summarize the entire thread (creates lossy overview)
- Start the new thread without user confirmation of the prompt
- Include files unrelated to the new thread goal
- **Investigate or read files yourself** — the next thread does the investigation; handoff only extracts what's already known
- Trial-and-error with clipboard commands — use the script path provided below

## Workflow

### Get Goal

Ask the user: "What would you like to work on next?"

Examples:

- "implement this for teams as well, not just individual users"
- "execute phase one of the created plan"
- "find other places in the codebase that need this fix"

### Extract Context

From what's already discussed in the current thread, extract:

- Relevant files that the new task depends on
- Key decisions or design choices made
- Any partial work or in-progress changes
- Configuration or setup details relevant to the new task

**Do NOT read additional files** — use only context already in the conversation. If the user has already explained the problem (e.g., "wrong endpoint", "404 error"), include that directly. Investigation is the next thread's job.

### Generate Draft Prompt

Create a draft prompt that includes:

- Brief context summary (what has been done, current state)
- Specific task goal
- Key files and their relevance
- Any constraints or requirements mentioned

Present this draft to the user for review and editing.

### Confirm and Handoff

Once the user approves the prompt:

- Copy the prompt to clipboard using the script `.agents/skills/handoff/scripts/copy-to-clipboard.sh`
  ```bash
  .agents/skills/handoff/scripts/copy-to-clipboard.sh "prompt text here"
  ```
- The user can then start a new thread with the approved prompt (already in clipboard)
