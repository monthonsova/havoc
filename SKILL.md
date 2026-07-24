---
name: efficient-reading-and-recording
description: Guidelines for highly efficient file reading, code analysis, and recording knowledge during coding tasks.
---

# Efficient Reading & Knowledge Recording Guidelines

This document serves as a reminder and guide for the AI agent (Antigravity) to operate with maximum efficiency when inspecting code and to systematically document knowledge.

## 1. Efficient File Reading
- **Minimize Context Bloat**: Do not read entire files unless they are small (< 300 lines). Always specify target line ranges using `StartLine` and `EndLine` parameters in `view_file`.
- **Pre-Scan with Commands**: When looking for specific patterns, classes, functions, or comments in large files, use shell commands (like PowerShell's `Select-String` or ripgrep) to pinpoint the exact line numbers before reading.
- **Avoid Redundant Reads**: Once file sections are read, keep track of their structure and contents in your memory/context instead of reading them repeatedly.

## 2. Systematic Knowledge Recording
- **Create Artifacts Strategicially**: Document research findings, architecture notes, and planned changes in the `.md` artifacts under the conversation directory (e.g., `implementation_plan.md`, `research_notes.md`).
- **Update walkthrough.md**: When changes are completed, document the exact modifications, testing results, and verification steps in `walkthrough.md`.
- **Use Scratch Directory**: Store temporary test scripts, helper tools, and quick validation scripts in the `<appDataDir>/brain/<conversation-id>/scratch/` directory.
- **Maintain a TODO list**: Create and update a `task.md` to track progress sequentially, marking items as `[ ]`, `[/]` (in progress), and `[x]` (completed).
