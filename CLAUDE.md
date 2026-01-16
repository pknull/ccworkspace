# Project Context

This project uses the **Asha** framework for session coordination and memory persistence.

## Quick Reference

**Framework:** Asha plugin provides CORE.md and operational protocols via SessionStart hook.

**Memory Bank:** Project context stored in `Memory/*.md` files.

## Commands

| Command | Purpose |
|---------|---------|
| `/asha:save` | Save session context to Memory Bank, archive session, refresh index, commit |
| `/asha:index` | Index files for semantic search (use `--full` for complete reindex, `--check` for dependency verification) |

## Tools

Tool paths are provided by the Asha plugin via session context. Common operations:

```bash
# Semantic search (requires Ollama running)
# Path provided in session context as: memory_index.py search "your query"

# Pattern lookup from ReasoningBank
# Path provided in session context as: reasoning_bank.py query --context "situation"

# Check vector DB dependencies
# Path provided in session context as: memory_index.py check
```

## Memory Files

| File | Purpose | Update Frequency |
|------|---------|------------------|
| `Memory/activeContext.md` | Current project state, recent activities | Every session |
| `Memory/projectbrief.md` | Project scope, objectives, constraints | Rarely |
| `Memory/communicationStyle.md` | Voice, persona, authority hierarchy | Rarely |
| `Memory/workflowProtocols.md` | Validated patterns, anti-patterns | When patterns discovered |
| `Memory/techEnvironment.md` | Technical stack, conventions | When stack changes |

## Session Workflow

1. **Start:** Read `Memory/activeContext.md` for context
2. **Work:** Operations logged automatically via hooks
3. **End:** Run `/asha:save` to synthesize and persist learnings

## Code Style

- Follow existing patterns in the codebase
- Use authority markers when uncertain: `[Inference]`, `[Speculation]`, `[Unverified]`
- Reference code locations as `file_path:line_number`
