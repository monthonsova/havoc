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
- **Create Artifacts Strategically**: Document research findings, architecture notes, and planned changes in the `.md` artifacts under the conversation directory (e.g., `implementation_plan.md`, `research_notes.md`).
- **Update walkthrough.md**: When changes are completed, document the exact modifications, testing results, and verification steps in `walkthrough.md`.
- **Use Scratch Directory**: Store temporary test scripts, helper tools, and quick validation scripts in the `<appDataDir>/brain/<conversation-id>/scratch/` directory.
- **Maintain a TODO list**: Create and update a `task.md` to track progress sequentially, marking items as `[ ]`, `[/]` (in progress), and `[x]` (completed).

---

## 3. Roblox Luau Optimization & Stability Rules
- **Non-Recursive Joint Scanning**: Never use `model:FindFirstChild(name, true)` inside high-frequency frame loops or scanning loops. Always query top-level children directly (`model:FindFirstChild(name)`) to avoid CPU stutters when hundreds of models exist in Workspace.
- **Safe Value Dereferencing**: Always check that `instance.Parent ~= nil` and wrap `.Value` queries in `pcall()` when inspecting ValueObjects (`BoolValue`, `NumberValue`, `StringValue`) that can be deleted dynamically by game scripts.
- **Raycast Exclusion Safety**: Verify that `FilterDescendantsInstances` arrays only contain non-nil Instances with active parents (`inst.Parent ~= nil`) to prevent Roblox physics engine exceptions.
- **Legacy Property Fallbacks**: Use `part.AssemblyLinearVelocity or part.Velocity or Vector3.zero` to guarantee compatibility across diverse execution environments and older engine releases.
- **Defensive Type Checking**: Before executing cross-module hooks or callbacks (e.g., `applySilentFire`), always verify function existence via `type(fn) == "function"`.

---

## 4. Potassium Executor Capabilities & API Reference

Potassium is an advanced Roblox executor environment providing comprehensive C-closure hooking, memory reflection, environment manipulation, and off-thread execution capabilities.

### Key Libraries & APIs:
* **Closure & Function Hooking**:
  - `hookfunction(oldFn, newFn)`: Hooks a Lua or C closure and returns the original function.
  - `restorefunction(fn)`: Restores a hooked function back to its original implementation.
  - `oth.hook(targetFn, hookFn)`: Off-Thread Hooking mechanism allowing secure C-function hooking on isolated threads to bypass detection.
  - `oth.get_root_callback()` / `oth.unhook()`: Tools for managing off-thread hooks.
  - `isfunctionhooked(fn)` / `iscclosure(fn)` / `islclosure(fn)` / `isexecutorclosure(fn)`: Type and status checking for functions.
  - `setstackhidden(fn, state)`: Hides execution frames from call-stack inspection anti-cheats.
* **Metatable & Environment Manipulation**:
  - `hookmetamethod(object, method, newFn)`: Direct hooking of metatable methods (e.g., `__namecall`, `__index`, `__newindex`).
  - `getnamecallmethod()` / `setnamecallmethod(method)`: Access and override active `__namecall` method names.
  - `getsenv(script)` / `getgenv()` / `getrenv()`: Script, executor, and Roblox engine environment inspection.
  - `setreadonly(table, bool)` / `isreadonly(table)`: Toggle metatable write protections.
* **Reflection & Memory Inspection**:
  - `getgc(includeTables)` / `filtergc(...)`: Garbage collection scanning to locate hidden instances, functions, and active tables.
  - `getloadedmodules()` / `getrunningscripts()`: Retrieve module and script arrays.
  - `gethiddenproperty(inst, prop)` / `sethiddenproperty(inst, prop, val)`: Access non-scriptable internal properties.
  - `getbspval(inst)`: Read binary string properties (e.g., Terrain physics, Mesh data).
* **Signal & RakNet Networking**:
  - `raknet.add_send_hook(callback)`: Hook low-level RakNet network packets before transmission.
  - `raknet.send(payload, ...)`: Direct low-level packet dispatching.
  - `getconnections(signal)` / `firesignal(signal)` / `replicatesignal(signal)`: Inspect and invoke RBXScriptSignal connections.
* **Input & Render**:
  - `mousemoverel(dx, dy)` / `mousemoveabs(x, y)` / `mouse1click()` / `keypress(code)`: User input injection.
  - `Drawing.new(type)` / `DrawingImmediate`: Vector overlay rendering.
