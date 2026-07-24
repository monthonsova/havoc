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

## 4. Potassium Complete API Reference (196 Functions across 20 Libraries)

### A. Off-Thread & Closure Hooking
- `hookfunction(oldFn, newFn)` / `restorefunction(fn)`: Hooks/restores Lua or C closures.
- `oth.hook(target, hook)` / `oth.unhook(target)`: Off-Thread Hooking mechanism using isolated threads to bypass C-stack checks.
- `oth.get_root_callback()` / `oth.get_original_thread()` / `oth.is_hook_thread()`: Context management for off-thread hooks.
- `setstackhidden(fn, state)`: Hides execution frames from call-stack inspection.
- `iscclosure(fn)` / `islclosure(fn)` / `isnewcclosure(fn)` / `isexecutorclosure(fn)` / `isfunctionhooked(fn)`: Closure type identification.

### B. Metatable & Environment Control
- `hookmetamethod(obj, method, newFn)`: Direct metatable method overriding (`__namecall`, `__index`, `__newindex`).
- `getnamecallmethod()` / `setnamecallmethod(method)`: Access and modify global `__namecall` method names.
- `getrawmetatable(tbl)` / `setrawmetatable(tbl, meta)` / `getgenv()` / `getrenv()` / `getsenv(script)` / `gettenv(thread)`: Environment and metatable inspection ignoring protections.
- `setreadonly(tbl, bool)` / `isreadonly(tbl)` / `makereadonly(tbl)` / `makewritable(tbl)`: Metatable write access control.

### C. Garbage Collection & Memory Reflection
- `getgc(includeTables)` / `filtergc(...)`: Garbage collection scanner for active tables/functions.
- `getreg()` / `debug.getregistry()`: Internal Lua registry table access.
- `gethiddenproperties` / `gethiddenproperty` / `sethiddenproperty`: Access non-scriptable internal properties.
- `getbspval(inst)`: Read binary string properties (`Terrain.SmoothGrid`, `PhysicsData`).

### D. Networking & Signals
- `raknet.add_send_hook(cb)` / `raknet.remove_send_hook(cb)` / `raknet.send(payload, ...)`: Low-level RakNet packet interception and injection.
- `firesignal(signal)` / `replicatesignal(signal)` / `cansignalreplicate(signal)`: Signal invocation and replication.
- `getconnections(signal)` / `getconnection(signal)`: Inspect script signal connections.

### E. Actor & Multi-Threading
- `create_comm_channel()` / `get_comm_channel()`: Inter-actor communication channels.
- `getactors()` / `getactorthreads()` / `getdeletedactors()`: Actor hierarchy tracking.
- `run_on_actor(actor, code)` / `run_on_thread(thread, code)`: Parallel script execution.

### F. Cryptography & FileSystem
- `crypt.encrypt` / `crypt.decrypt` / `crypt.hash` / `crypt.hmac` / `crypt.lz4compress` / `crypt.lz4decompress`: Encryption and compression utilities.
- `readfile` / `writefile` / `appendfile` / `loadfile` / `dofile` / `listfiles` / `makefolder` / `delfile`: Workspace file operations.

### G. Input & Graphics
- `mousemoverel` / `mousemoveabs` / `mouse1click` / `mouse2click` / `keypress` / `keyrelease`: Direct OS/Roblox input injection.
- `Drawing.new` / `DrawingImmediate.GetPaint` / `Shader`: 2D vector drawing and HLSL shader rendering.
