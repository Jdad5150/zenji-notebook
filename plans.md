# Zenji Notebook — Development Roadmap & Architecture Guide
## A Zig + Svelte + Tailwind Jupyter-Compatible Notebook
## Part of the Zenji Toolkit

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Kernel & OS Compatibility](#2-kernel--os-compatibility)
3. [Monorepo Structure](#3-monorepo-structure)
4. [Build System](#4-build-system)
5. [Phase 0 — Foundation & Tooling](#5-phase-0--foundation--tooling)
6. [Phase 1 — Minimal Zig Server](#6-phase-1--minimal-zig-server)
7. [Phase 2 — ZeroMQ Integration](#7-phase-2--zeromq-integration)
8. [Phase 3 — Jupyter Wire Protocol](#8-phase-3--jupyter-wire-protocol)
9. [Phase 4 — Kernel Manager](#9-phase-4--kernel-manager)
10. [Phase 5 — WebSocket Bridge](#10-phase-5--websocket-bridge)
11. [Phase 6 — REST API (Contents & Sessions)](#11-phase-6--rest-api-contents--sessions)
12. [Phase 7 — Svelte Frontend Foundation](#12-phase-7--svelte-frontend-foundation)
13. [Phase 8 — Code Editor & Cell Management](#13-phase-8--code-editor--cell-management)
14. [Phase 9 — Output Rendering](#14-phase-9--output-rendering)
15. [Phase 10 — Multi-Kernel Support](#15-phase-10--multi-kernel-support)
16. [Phase 11 — Polish & UX](#16-phase-11--polish--ux)
17. [Phase 12 — Packaging & Distribution](#17-phase-12--packaging--distribution)
18. [Phase 13 — Advanced Features](#18-phase-13--advanced-features)
19. [Testing Strategy](#19-testing-strategy)
20. [Reference Materials](#20-reference-materials)
21. [Risk Assessment & Mitigations](#21-risk-assessment--mitigations)

---

## 1. Project Overview

### What We're Building

A Jupyter-compatible notebook server and frontend that:

- Replaces the Python Tornado server with a Zig http.zig server
- Replaces the JupyterLab TypeScript/Lumino frontend with Svelte + Tailwind
- Implements the Jupyter Wire Protocol (v5.4) over ZeroMQ
- Supports Python (IPyKernel), R (IRKernel), and Julia (IJulia) kernels
- Ships as a single binary with embedded frontend assets
- Is 50-500x faster server overhead than Python Jupyter
- Has an 80x smaller frontend bundle than JupyterLab

### What We're NOT Building

- We are NOT building new kernels (we reuse existing ones)
- We are NOT inventing a new protocol (we implement the existing Jupyter spec)
- We are NOT building a cloud platform (this is a local-first tool)
- We are NOT rewriting JupyterHub (that's a separate concern)

### Design Principles

1. **Zero unnecessary overhead** — every layer compiles away abstractions
2. **Single binary distribution** — one file, no dependencies (besides kernels)
3. **Protocol compatibility** — existing kernels work without modification
4. **Simplicity over features** — do less, but do it perfectly
5. **Fast by default** — performance is not an optimization, it's the architecture

---

## 2. Kernel & OS Compatibility

### Critical Question: Is This a Single Codebase?

**YES — the zenji-notebook server itself is a single codebase.** Zig's build system
and cross-compilation make this straightforward. However, there are important
nuances to understand:

### The Kernels Are NOT Part of Your Codebase

```
zenji-notebook (your code)   Kernels (NOT your code)
┌─────────────────┐          ┌─────────────────────┐
│ Zig Server      │── ZMQ ──>│ IPyKernel (Python)  │ <- user installs via pip
│ Svelte Frontend │── ZMQ ──>│ IRKernel (R)        │ <- user installs via R
│ (single binary) │── ZMQ ──>│ IJulia (Julia)      │ <- user installs via Pkg
└─────────────────┘          └─────────────────────┘
     YOUR CODE                  THEIR CODE
     Cross-compiled             Already cross-platform
     by Zig                     (runs in their runtime)
```

The kernels are **separate processes** that communicate over ZeroMQ TCP sockets.
They already work on all major OSes because they run inside their respective
language runtimes (Python, R, Julia). You don't ship them. The user already
has them installed.

### What Differs Per OS

```
                        Linux       macOS       Windows
---------------------------------------------------------------
Process spawning        fork/exec   fork/exec   CreateProcess
Signal handling         SIGINT      SIGINT      GenerateConsoleCtrlEvent
File paths              /home/      /Users/     C:\Users\
Kernel spec locations   ~/.local/   ~/Library/  %APPDATA%\
ZeroMQ transport        tcp://      tcp://      tcp://
Line endings            LF          LF          CRLF (in files)
Default shell           /bin/sh     /bin/sh     cmd.exe
```

### How Zig Handles This (Beautifully)

```zig
const builtin = @import("builtin");

fn getKernelSpecDirs(allocator: Allocator) ![][]const u8 {
    var dirs = std.ArrayList([]const u8).init(allocator);

    switch (builtin.os.tag) {
        .linux => {
            const home = std.os.getenv("HOME") orelse return error.NoHome;
            try dirs.append(try std.fmt.allocPrint(
                allocator, "{s}/.local/share/jupyter/kernels", .{home}
            ));
            try dirs.append("/usr/share/jupyter/kernels");
            try dirs.append("/usr/local/share/jupyter/kernels");
        },
        .macos => {
            const home = std.os.getenv("HOME") orelse return error.NoHome;
            try dirs.append(try std.fmt.allocPrint(
                allocator, "{s}/Library/Jupyter/kernels", .{home}
            ));
            try dirs.append("/usr/local/share/jupyter/kernels");
        },
        .windows => {
            const appdata = std.os.getenv("APPDATA") orelse return error.NoAppData;
            try dirs.append(try std.fmt.allocPrint(
                allocator, "{s}\\jupyter\\kernels", .{appdata}
            ));
        },
        else => return error.UnsupportedOS,
    }

    return dirs.toOwnedSlice();
}
```

### Cross-Compilation Targets

```bash
zig build -Dtarget=x86_64-linux-gnu
zig build -Dtarget=x86_64-macos
zig build -Dtarget=aarch64-macos        # Apple Silicon
zig build -Dtarget=x86_64-windows-gnu
zig build -Dtarget=aarch64-linux-gnu    # Linux ARM
```

### ZeroMQ Linking Strategy

```
Option A: Dynamic linking (easier, user needs libzmq installed)
Option B: Static linking (preferred — true single binary)
Option C: Vendor libzmq source (most portable)
```

**Recommendation: Option C** — Vendor libzmq. Zig can compile C code natively.

```zig
// build.zig — Compile libzmq from source
const libzmq = b.addStaticLibrary(.{
    .name = "zmq",
    .target = target,
    .optimize = optimize,
});
libzmq.addCSourceFiles(&.{
    "vendor/libzmq/src/address.cpp",
    "vendor/libzmq/src/clock.cpp",
    "vendor/libzmq/src/ctx.cpp",
}, &.{});
libzmq.linkLibC();
libzmq.linkLibCpp();

exe.linkLibrary(libzmq);
```

---

## 3. Monorepo Structure

```
zenji-notebook/
|
├── build.zig
├── build.zig.zon
├── README.md
├── LICENSE
|
├── vendor/
│   └── libzmq/
│       ├── include/
│       │   └── zmq.h
│       └── src/
│           └── *.cpp
|
├── src/
│   ├── main.zig
│   |
│   ├── server/
│   │   ├── server.zig
│   │   ├── router.zig
│   │   ├── static.zig
│   │   └── middleware.zig
│   |
│   ├── api/
│   │   ├── kernels.zig
│   │   ├── kernelspecs.zig
│   │   ├── contents.zig
│   │   ├── sessions.zig
│   │   └── config.zig
│   |
│   ├── ws/
│   │   ├── handler.zig
│   │   └── bridge.zig
│   |
│   ├── kernel/
│   │   ├── manager.zig
│   │   ├── process.zig
│   │   ├── spec.zig
│   │   ├── connection.zig
│   │   └── pool.zig
│   |
│   ├── protocol/
│   │   ├── message.zig
│   │   ├── wire.zig
│   │   ├── hmac.zig
│   │   ├── header.zig
│   │   └── channel.zig
│   |
│   ├── transport/
│   │   ├── zmq.zig
│   │   ├── context.zig
│   │   ├── socket.zig
│   │   └── poller.zig
│   |
│   ├── notebook/
│   │   ├── format.zig
│   │   ├── io.zig
│   │   └── convert.zig
│   |
│   ├── auth/
│   │   ├── token.zig
│   │   └── cookie.zig
│   |
│   └── util/
│       ├── uuid.zig
│       ├── json.zig
│       ├── logging.zig
│       ├── platform.zig
│       └── mime.zig
|
├── frontend/
│   ├── package.json            # bun-compatible (scripts remain, Bun reads package.json)
│   ├── bun.lockb               # generated by Bun; commit for reproducible installs
│   ├── svelte.config.js
│   ├── tailwind.config.cjs
│   ├── postcss.config.cjs
│   ├── tsconfig.json
│   |
│   ├── src/
│   │   ├── lib/
│   │   │   ├── stores/
│   │   │   │   ├── kernel.ts
│   │   │   │   ├── notebook.ts
│   │   │   │   ├── cells.ts
│   │   │   │   ├── files.ts
│   │   │   │   ├── websocket.ts
│   │   │   │   ├── settings.ts
│   │   │   │   └── ui.ts
│   │   │   |
│   │   │   ├── jupyter/
│   │   │   │   ├── client.ts
│   │   │   │   ├── messages.ts
│   │   │   │   ├── channel.ts
│   │   │   │   └── types.ts
│   │   │   |
│   │   │   ├── editor/
│   │   │   │   ├── setup.ts       # CodeMirror integration (lazy-loaded)
│   │   │   │   ├── keybindings.ts
│   │   │   │   ├── themes.ts
│   │   │   │   └── languages.ts
│   │   │   |
│   │   │   └── utils/
│   │   │       ├── uuid.ts
│   │   │       ├── ansi.ts
│   │   │       ├── debounce.ts
│   │   │       └── markdown.ts
│   │   |
│   │   ├── lib-components/       # small wrappers around Flowbite Svelte + specialized widgets
│   │   │   ├── layout/
│   │   │   │   ├── Toolbar.svelte
│   │   │   │   ├── Sidebar.svelte
│   │   │   │   ├── StatusBar.svelte
│   │   │   │   └── Splitpane.svelte   # uses svelte-split or similar
│   │   │   |
│   │   │   ├── notebook/
│   │   │   │   ├── Notebook.svelte
│   │   │   │   ├── Cell.svelte
│   │   │   │   ├── CodeCell.svelte     # lazy-loads CodeMirror
│   │   │   │   ├── MarkdownCell.svelte
│   │   │   │   ├── RawCell.svelte
│   │   │   │   ├── CellToolbar.svelte
│   │   │   │   └── AddCellButton.svelte
│   │   │   |
│   │   │   ├── outputs/
│   │   │   │   ├── CellOutput.svelte
│   │   │   │   ├── StreamOutput.svelte
│   │   │   │   ├── ErrorOutput.svelte
│   │   │   │   ├── RichOutput.svelte
│   │   │   │   ├── ImageOutput.svelte
│   │   │   │   ├── HtmlOutput.svelte
│   │   │   │   ├── PlotOutput.svelte
│   │   │   │   ├── DataFrameOutput.svelte
│   │   │   │   └── LatexOutput.svelte
│   │   │   |
│   │   │   ├── filebrowser/
│   │   │   │   ├── FileBrowser.svelte
│   │   │   │   ├── FileTree.svelte
│   │   │   │   └── FileItem.svelte
│   │   │   |
│   │   │   └── shared/
│   │   │       ├── CommandPalette.svelte  # custom, keyboard-first
│   │   │       ├── Modal.svelte
│   │   │       ├── Dropdown.svelte
│   │   │       ├── Toast.svelte
│   │   │       └── Spinner.svelte
│   │   |
│   │   └── routes/                    # SvelteKit-style routing
│   │       ├── +layout.svelte
│   │       ├── +page.svelte
│   │       └── notebooks/
│   │           └── [id]/
│   │               └── +page.svelte
│   |
│   ├── static/
│   │   ├── favicon.svg
│   │   └── fonts/
│   │       └── JetBrainsMono.woff2
│   |
│   └── .svelte-kit/ or build/         # SvelteKit output (depends on adapter)
|
└── tests/
    ├── backend/
    │   ├── protocol_test.zig
    │   ├── zmq_test.zig
    │   ├── kernel_test.zig
    │   ├── api_test.zig
    │   └── notebook_test.zig
    |
    ├── frontend/
    │   ├── stores.test.ts
    │   ├── jupyter.test.ts
    │   └── components.test.ts
    |
    └── integration/
        ├── python_kernel_test.zig
        ├── r_kernel_test.zig
        └── julia_kernel_test.zig
```

---

## 4. Build System

### Master build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const static_zmq = b.option(bool, "static", "Statically link libzmq") orelse true;

    const libzmq = buildLibZmq(b, target, optimize);

    const frontend_step = buildFrontend(b);

    const exe = b.addExecutable(.{
        .name = "zenji-notebook",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (static_zmq) {
        exe.linkLibrary(libzmq);
    } else {
        exe.linkSystemLibrary("zmq");
    }
    exe.linkLibC();

    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("httpz", httpz.module("httpz"));

    exe.step.dependOn(frontend_step);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run zenji-notebook server");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "tests/backend/protocol_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
```

### Development Workflow

```bash
# First Time Setup
cd frontend && npm install && cd ..

# Development (two terminals)
# Terminal 1: Svelte dev server with HMR
cd frontend && npm run dev          # localhost:5173

# Terminal 2: Zig backend
zig build dev && ./zig-out/bin/zenji-notebook-dev --port 8888

# Production Build
zig build -Doptimize=ReleaseFast

# Cross Compile
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows-gnu
```

---

## 5. Phase 0 — Foundation & Tooling

**Duration: 1-2 days**
**Goal: Project scaffolding, dependencies, build system working**

### Checkpoints

- [X] Initialize git repo
- [X] Create directory structure
- [X] Initialize Zig project with build.zig
- [X] Add http.zig as a dependency in build.zig.zon
- [X] Vendor libzmq source (or start with dynamic linking)
- [X] Verify `zig build` compiles a hello world server
- [X] Initialize Svelte project in frontend/
- [X] Install Tailwind CSS + PostCSS
- [X] Verify `npm run build` produces dist/ output
- [X] Verify Zig can @embedFile a test file from frontend/dist/
- [X] Create a basic "hello world" that serves an embedded HTML page

### Validation Test

```bash
zig build run
# Visit http://localhost:8888
# See "Zenji Notebook — Coming Soon" page served from embedded Svelte build
```

---

## 6. Phase 1 — Minimal Zig Server

**Duration: 2-3 days**
**Goal: HTTP server with routing, static file serving, basic middleware**

### Checkpoints

- [X] Set up http.zig server with configurable port
- [X] Implement route registration for all Jupyter API paths
- [X] Implement static file serving from embedded assets
- [X] Implement static file serving from filesystem (dev mode)
- [X] Add SPA fallback (unknown routes -> index.html)
- [ ] Implement basic request logging middleware
- [ ] Implement CORS headers middleware
- [ ] Implement token-based authentication middleware
- [X] Add CLI argument parsing (--port, --token, --no-auth, --dev)
- [X] Implement MIME type detection for static files
- [ ] Add graceful shutdown on SIGINT/SIGTERM

### Stub API Responses

```zig
fn listKernels(response: *http.Response, request: *http.Request) !void {
    try response.json(.{ .kernels = .{} }, .{});
}

fn listKernelSpecs(response: *http.Response, request: *http.Request) !void {
    try response.json(.{
        .default = "python3",
        .kernelspecs = .{
            .python3 = .{
                .name = "python3",
                .spec = .{
                    .display_name = "Python 3",
                    .language = "python",
                },
            },
        },
    }, .{});
}
```

### Validation Test

```bash
zig build run
curl http://localhost:8888/api/kernelspecs   # Returns valid JSON
curl http://localhost:8888/                   # Returns embedded index.html
```

---

## 7. Phase 2 — ZeroMQ Integration

**Duration: 3-4 days**
**Goal: Clean ZMQ C interop layer, can create sockets and send/receive**

### Checkpoints

- [ ] Create zmq.zig C import wrapper
- [ ] Implement ZMQ context creation/destruction
- [ ] Implement socket creation for all 5 channel types
- [ ] Implement socket binding to tcp://127.0.0.1:PORT
- [ ] Implement port scanning to find available ports
- [ ] Implement multi-part message send
- [ ] Implement multi-part message receive
- [ ] Implement ZMQ polling (zmq_poll) for multiplexing
- [ ] Implement proper cleanup/resource deallocation
- [ ] Write tests for ZMQ send/receive round-trip
- [ ] Test with a simple Python ZMQ echo server

### Validation Test

```python
# test_echo.py
import zmq
ctx = zmq.Context()
sock = ctx.socket(zmq.REP)
sock.bind("tcp://127.0.0.1:5555")
while True:
    msg = sock.recv_string()
    print(f"Got: {msg}")
    sock.send_string(f"Echo: {msg}")
```

---

## 8. Phase 3 — Jupyter Wire Protocol

**Duration: 3-5 days**
**Goal: Can construct, serialize, sign, and parse Jupyter messages**

### The Wire Protocol Format

```
A Jupyter message on ZMQ is a multi-part message:

Frame 0:    [identity]              (ZMQ ROUTER identity)
Frame N:    <IDS|MSG>               (delimiter)
Frame N+1:  HMAC-SHA256 signature   (hex string)
Frame N+2:  header                  (JSON)
Frame N+3:  parent_header           (JSON)
Frame N+4:  metadata                (JSON)
Frame N+5:  content                 (JSON)
Frame N+6+: [binary buffers]        (optional)
```

### Checkpoints

- [ ] Define all Jupyter message types as Zig structs
- [ ] Implement message header construction (msg_id, session, timestamp)
- [ ] Implement UUID v4 generation
- [ ] Implement ISO 8601 timestamp generation
- [ ] Implement JSON serialization of message parts
- [ ] Implement JSON deserialization of message parts
- [ ] Implement HMAC-SHA256 signing of messages
- [ ] Implement HMAC-SHA256 verification of received messages
- [ ] Implement multi-part ZMQ message assembly (with delimiter)
- [ ] Implement multi-part ZMQ message parsing (from delimiter)
- [ ] Implement message routing (determine channel from msg_type)
- [ ] Write comprehensive tests for serialization round-trips
- [ ] Write tests for HMAC signing/verification

### Message Types to Implement (Priority Order)

```
MUST HAVE (Phase 3):
├── kernel_info_request / kernel_info_reply
├── execute_request / execute_reply
├── status (IOPub)
├── stream (IOPub — stdout/stderr)
├── execute_result (IOPub)
├── error (IOPub)
├── display_data (IOPub)
└── shutdown_request / shutdown_reply

SHOULD HAVE (Phase 6+):
├── complete_request / complete_reply        (autocomplete)
├── inspect_request / inspect_reply          (tooltips)
├── is_complete_request / is_complete_reply
├── interrupt_request / interrupt_reply
├── comm_open / comm_msg / comm_close        (widgets)
├── input_request / input_reply              (stdin)
└── history_request / history_reply
```

### Validation Test

```zig
const msg = JupyterMessage.kernelInfoRequest(session_id);
const frames = try msg.toZmqFrames(allocator, hmac_key);
const parsed = try JupyterMessage.fromZmqFrames(allocator, frames, hmac_key);
try std.testing.expectEqualStrings("kernel_info_request", parsed.header.msg_type);
```

---

## 9. Phase 4 — Kernel Manager

**Duration: 3-5 days**
**Goal: Can discover, start, monitor, and stop kernels**

### Checkpoints

- [ ] Implement kernel spec discovery (scan standard directories per OS)
- [ ] Parse kernel.json files
- [ ] Implement connection file generation (JSON with ports + HMAC key)
- [ ] Implement port allocation (find 5 free TCP ports)
- [ ] Implement kernel process spawning
- [ ] Implement kernel startup detection (kernel_info_request handshake)
- [ ] Implement kernel heartbeat monitoring
- [ ] Implement kernel state tracking (starting -> idle -> busy -> dead)
- [ ] Implement graceful kernel shutdown
- [ ] Implement forceful kernel termination (kill after timeout)
- [ ] Implement kernel restart
- [ ] Implement kernel interrupt (SIGINT on Linux/macOS)
- [ ] Implement connection file cleanup on kernel stop
- [ ] Implement multi-kernel registry (HashMap of kernel_id -> KernelProcess)
- [ ] Handle kernel crash detection and auto-cleanup

### Kernel Spec Format (kernel.json)

```json
{
    "argv": [
        "python3",
        "-m",
        "ipykernel_launcher",
        "-f",
        "{connection_file}"
    ],
    "display_name": "Python 3",
    "language": "python"
}
```

### Connection File Format

```json
{
    "ip": "127.0.0.1",
    "transport": "tcp",
    "shell_port": 52341,
    "iopub_port": 52342,
    "stdin_port": 52343,
    "control_port": 52344,
    "hb_port": 52345,
    "key": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "signature_scheme": "hmac-sha256",
    "kernel_name": "python3"
}
```

### Validation Test

```bash
curl -X POST http://localhost:8888/api/kernels -d '{"name":"python3"}'
# Returns: {"id": "abc-123", "name": "python3", "execution_state": "starting"}

curl http://localhost:8888/api/kernels/abc-123
# Returns: {"id": "abc-123", "name": "python3", "execution_state": "idle"}

curl -X DELETE http://localhost:8888/api/kernels/abc-123
# Kernel terminated, cleaned up
```

---

## 10. Phase 5 — WebSocket Bridge

**Duration: 4-5 days**
**Goal: Browser can execute code via WebSocket -> ZMQ -> Kernel pipeline**

### THIS IS THE HARDEST PHASE

### Checkpoints

- [ ] Implement WebSocket upgrade on /api/kernels/:id/channels
- [ ] Implement WebSocket message receiving (JSON from browser)
- [ ] Implement WebSocket message sending (JSON to browser)
- [ ] Parse incoming WebSocket messages to determine target ZMQ channel
- [ ] Forward shell channel messages (browser -> ZMQ)
- [ ] Forward stdin channel messages (browser -> ZMQ)
- [ ] Forward control channel messages (browser -> ZMQ)
- [ ] Poll all 4 ZMQ channels for incoming messages
- [ ] Forward IOPub messages (ZMQ -> browser)
- [ ] Forward shell replies (ZMQ -> browser)
- [ ] Forward control replies (ZMQ -> browser)
- [ ] Add channel field to WebSocket messages for routing
- [ ] Handle multiple simultaneous WebSocket connections to same kernel
- [ ] Handle WebSocket disconnection (cleanup, but don't kill kernel)
- [ ] Handle kernel death while WebSocket is connected
- [ ] Implement message queuing for messages received before WS is ready
- [ ] Test full execute_request -> status:busy -> stream -> execute_result -> status:idle flow

### The Polling Loop (Core Design)

```
Thread 1 (WS Reader):
  Loop:
    Read WebSocket message
    Parse channel + message
    Send to appropriate ZMQ socket

Thread 2 (ZMQ Poller):
  Loop:
    zmq_poll on shell, iopub, stdin, control (timeout: 100ms)
    For each ready socket:
      Read ZMQ message
      Wrap with channel tag
      Send to WebSocket
```

### WebSocket Message Format

```json
// Browser -> Server
{
    "channel": "shell",
    "header": { "msg_type": "execute_request", "..." },
    "parent_header": {},
    "metadata": {},
    "content": { "code": "print('hello')", "..." }
}

// Server -> Browser
{
    "channel": "iopub",
    "header": { "msg_type": "stream", "..." },
    "parent_header": { "msg_id": "original-request-id", "..." },
    "metadata": {},
    "content": { "name": "stdout", "text": "hello\n" }
}
```

### Validation Test

```bash
# Use websocat to test
websocat ws://localhost:8888/api/kernels/KERNEL_ID/channels
# Send execute_request JSON
# Should receive: status:busy -> stream -> execute_result -> execute_reply -> status:idle
```

### MILESTONE: Backend Is Functionally Complete After This Phase

---

## 11. Phase 6 — REST API (Contents & Sessions)

**Duration: 2-3 days**
**Goal: File browser works, notebooks can be opened/saved**

### Checkpoints

#### Contents API
- [ ] GET /api/contents — list root directory
- [ ] GET /api/contents/:path — get file/directory info
- [ ] GET /api/contents/:path?content=1 — get file with content
- [ ] PUT /api/contents/:path — save/upload file
- [ ] POST /api/contents/:path — create new file/directory
- [ ] DELETE /api/contents/:path — delete file
- [ ] PATCH /api/contents/:path — rename/move file
- [ ] Implement directory listing
- [ ] Implement notebook reading (format: "json")
- [ ] Implement text file reading (format: "text")
- [ ] Implement binary file reading (format: "base64")
- [ ] Handle path traversal security (prevent ../ attacks)
- [ ] Implement root directory configuration (--notebook-dir flag)

#### Sessions API
- [ ] POST /api/sessions — create session
- [ ] GET /api/sessions — list active sessions
- [ ] GET /api/sessions/:id — get session info
- [ ] PATCH /api/sessions/:id — update session
- [ ] DELETE /api/sessions/:id — delete session

#### Notebook Format
- [ ] Parse .ipynb JSON (nbformat v4)
- [ ] Serialize .ipynb JSON
- [ ] Handle notebook metadata
- [ ] Handle cell metadata
- [ ] Handle output storage in cells

---

## 12. Phase 7 — Svelte Frontend Foundation

**Duration: 3-4 days**
**Goal: Basic app shell, routing, stores, API client**

### Checkpoints

- [ ] Set up Svelte + Vite + Tailwind + TypeScript
- [ ] Configure Tailwind with custom notebook theme colors
- [ ] Set up CSS custom properties for theming
- [ ] Import JetBrains Mono font
- [ ] Create App.svelte with layout (toolbar + sidebar + main)
- [ ] Implement Jupyter REST API client (typed fetch wrapper)
- [ ] Implement kernel store
- [ ] Implement WebSocket channel store
- [ ] Implement notebook store
- [ ] Implement cells store
- [ ] Implement files store
- [ ] Implement UI store
- [ ] Implement settings store (localStorage persisted)
- [ ] Wire up WebSocket connection on kernel start
- [ ] Wire up message routing (WebSocket -> cell outputs)
- [ ] Create Toolbar component
- [ ] Create Sidebar/FileBrowser component
- [ ] Create StatusBar component

### Vite Proxy Config

```typescript
// frontend/vite.config.ts
export default defineConfig({
    plugins: [svelte()],
    server: {
        port: 5173,
        proxy: {
            '/api': {
                target: 'http://localhost:8888',
                ws: true,
            },
        },
    },
});
```

---

## 13. Phase 8 — Code Editor & Cell Management

**Duration: 4-5 days**
**Goal: Can write code in cells, execute, see results**

### Checkpoints

#### CodeMirror Integration
- [ ] Install CodeMirror 6 + language packages
- [ ] Create CodeMirror setup with Python syntax highlighting
- [ ] Add R syntax highlighting
- [ ] Add Julia syntax highlighting
- [ ] Auto-detect language from kernel spec
- [ ] Configure dark theme matching Tailwind theme
- [ ] Implement Shift+Enter -> execute cell
- [ ] Implement Ctrl+Enter -> execute cell, stay
- [ ] Implement Alt+Enter -> execute cell, add below
- [ ] Implement Tab -> indent / autocomplete trigger
- [ ] Implement bracket/quote auto-pairing
- [ ] Implement line numbers
- [ ] Sync editor content -> cell store on change (debounced)

#### Cell Management
- [ ] Render list of cells from cells store
- [ ] Implement cell focus/selection
- [ ] Implement Add Code Cell / Add Markdown Cell
- [ ] Implement Delete Cell
- [ ] Implement Move Cell Up/Down
- [ ] Implement cell type switching
- [ ] Implement execution count display
- [ ] Implement cell status indicator (idle/running/queued)
- [ ] Implement cell toolbar (hover actions)
- [ ] Implement "Run All" / "Run All Above" / "Run All Below"
- [ ] Implement "Clear All Outputs"

#### Markdown Cells
- [ ] Render markdown when not focused
- [ ] Show raw source when editing
- [ ] Support code blocks with syntax highlighting
- [ ] Support LaTeX math (KaTeX)

#### Keyboard Shortcuts (Jupyter-Compatible)

```
Command Mode (cell selected, not editing):
  Enter       -> Edit mode
  Shift+Enter -> Run cell, move down
  A           -> Add cell above
  B           -> Add cell below
  DD          -> Delete cell
  M           -> Convert to markdown
  Y           -> Convert to code
  Up/Down     -> Navigate cells
  Ctrl+S      -> Save notebook
  II          -> Interrupt kernel
  00          -> Restart kernel

Edit Mode (typing in editor):
  Escape      -> Command mode
  Shift+Enter -> Run cell, move down
  Ctrl+Enter  -> Run cell, stay
  Alt+Enter   -> Run cell, add below
  Tab         -> Indent / autocomplete
```

---

## 14. Phase 9 — Output Rendering

**Duration: 3-4 days**
**Goal: All common output types render correctly**

### Checkpoints

#### Basic Outputs
- [ ] Stream output (stdout) — plain text, monospace
- [ ] Stream output (stderr) — warning colored
- [ ] Execute result — plain text
- [ ] Error output — traceback with ANSI color conversion
- [ ] Multiple outputs per cell

#### Rich Outputs (MIME-type based)
- [ ] text/plain
- [ ] text/html (sandboxed)
- [ ] image/png (base64 decoded)
- [ ] image/jpeg
- [ ] image/svg+xml
- [ ] text/markdown
- [ ] text/latex (KaTeX)
- [ ] application/json (formatted viewer)

#### Data Science Outputs
- [ ] Pandas DataFrame HTML tables (styled with Tailwind)
- [ ] Matplotlib plots (PNG/SVG)
- [ ] Plotly charts (lazy-load plotly.js, render interactive)
- [ ] Seaborn plots
- [ ] PIL/Pillow images
- [ ] R ggplot2 (SVG/PNG)
- [ ] Julia Plots.jl (SVG/PNG)

#### MIME Type Priority

```
const MIME_PRIORITY = [
    'application/vnd.plotly.v1+json',
    'text/html',
    'image/svg+xml',
    'image/png',
    'image/jpeg',
    'text/markdown',
    'text/latex',
    'application/json',
    'text/plain',
];
```

#### ANSI Color Conversion
- [ ] ANSI escape code -> HTML span converter
- [ ] Support 16 colors, 256 colors, 24-bit true color
- [ ] Support bold, italic, underline

#### Output UX
- [ ] Collapsible outputs
- [ ] Scrollable outputs (max-height)
- [ ] Clear Output button per cell
- [ ] Copy output to clipboard
- [ ] Large output warning

---

## 15. Phase 10 — Multi-Kernel Support

**Duration: 2-3 days**
**Goal: Python, R, and Julia kernels all work**

### Checkpoints

- [ ] Discover all installed kernel specs
- [ ] Display available kernels in UI (kernel picker)
- [ ] Kernel selection when creating new notebook
- [ ] Kernel switching on existing notebook
- [ ] CodeMirror language mode switching based on kernel
- [ ] Test with IPyKernel (Python)
- [ ] Test with IRKernel (R)
- [ ] Test with IJulia (Julia)
- [ ] Handle kernel-specific MIME types
- [ ] Update notebook metadata when kernel changes
- [ ] Show kernel language icon in toolbar

---

## 16. Phase 11 — Polish & UX

**Duration: 3-5 days**
**Goal: Feels professional, handles edge cases**

### Checkpoints

#### Command Palette
- [ ] Cmd+K / Ctrl+K command palette
- [ ] Search through all commands
- [ ] Show keyboard shortcuts
- [ ] Execute selected command

#### Theming
- [ ] Dark theme (default — Tokyo Night inspired)
- [ ] Light theme
- [ ] Theme toggle in toolbar
- [ ] Persist theme in localStorage
- [ ] CodeMirror theme synced with app theme

#### Notifications & Feedback
- [ ] Toast notifications for errors
- [ ] Toast for "Notebook saved"
- [ ] Confirmation dialogs for destructive actions
- [ ] Loading spinner during kernel startup

#### Autosave
- [ ] Debounced autosave (every 30 seconds if dirty)
- [ ] Save status in toolbar
- [ ] Ctrl+S / Cmd+S manual save

#### Error Handling
- [ ] Handle server disconnection gracefully
- [ ] Auto-reconnect WebSocket with backoff
- [ ] Handle kernel crash -> show error, offer restart
- [ ] Handle file save failure
- [ ] Prevent data loss (warn on close with unsaved changes)

#### Performance
- [ ] Virtualized cell list for notebooks with 100+ cells
- [ ] Lazy-load heavy output renderers (Plotly, KaTeX)
- [ ] Debounce editor -> store sync
- [ ] Efficient output appending

---

## 17. Phase 12 — Packaging & Distribution

**Duration: 2-3 days**
**Goal: Single binary distribution for all platforms**

### Checkpoints

- [ ] Production build compiles frontend and embeds in binary
- [ ] Cross-compile for Linux x86_64
- [ ] Cross-compile for Linux aarch64
- [ ] Cross-compile for macOS x86_64
- [ ] Cross-compile for macOS aarch64 (Apple Silicon)
- [ ] Cross-compile for Windows x86_64
- [ ] Verify all cross-compiled binaries work
- [ ] Strip debug symbols for release builds
- [ ] Document binary sizes
- [ ] GitHub Actions CI pipeline
- [ ] Release automation (tag -> build -> GitHub release)
- [ ] Installation instructions
- [ ] Brew formula (macOS)
- [ ] Docker image (optional)

### Binary Size Targets

```
Linux x86_64:   ~8-15MB
Linux aarch64:  ~8-15MB
macOS x86_64:   ~8-15MB
macOS aarch64:  ~8-15MB
Windows x86_64: ~10-18MB

Compare: pip install jupyterlab = 500MB+
```

### Distribution

```bash
# User experience:
curl -L https://github.com/you/zenji-notebook/releases/latest/download/zenji-notebook-linux-x64 -o zenji-notebook
chmod +x zenji-notebook
./zenji-notebook
# That's it.
```

---

## 18. Phase 13 — Advanced Features

**Duration: Ongoing**
**Goal: Features that make ZigBook better than Jupyter**

### Autocomplete
- [ ] Implement complete_request / complete_reply
- [ ] CodeMirror autocomplete popup
- [ ] Tab completion

### Inspection / Tooltips
- [ ] Implement inspect_request / inspect_reply
- [ ] Shift+Tab docstring/signature popup

### Terminal Emulator
- [ ] Embed xterm.js terminal
- [ ] WebSocket to PTY on server
- [ ] Multiple terminal tabs

### Variable Explorer
- [ ] Side panel showing variables
- [ ] Names, types, values
- [ ] Click to expand complex objects

### Export
- [ ] Export as .py
- [ ] Export as .html
- [ ] Export as .pdf

### Git Integration (Optional)
- [ ] Git status of notebook files
- [ ] Visual diff of .ipynb changes

---

## 19. Testing Strategy

### Backend Tests (Zig)

```
Level 1: Unit Tests
  - Protocol message serialization/deserialization
  - HMAC signing/verification
  - UUID generation
  - Notebook format parsing
  - Path security

Level 2: Integration Tests
  - ZMQ send/receive
  - Kernel spec discovery
  - Connection file generation
  - HTTP API responses

Level 3: End-to-End Tests
  - Start kernel -> execute code -> verify output
  - WebSocket full message flow
  - File save/load round-trip
  - Kernel interrupt/restart
```

### Frontend Tests (Svelte/TypeScript)

```
Level 1: Unit Tests (vitest)
  - Store logic
  - Message construction
  - ANSI conversion
  - MIME type priority

Level 2: Component Tests (testing-library/svelte)
  - Cell rendering
  - Output rendering
  - Toolbar states

Level 3: E2E Tests (Playwright)
  - Full workflow: open -> type -> execute -> see output
  - Keyboard shortcuts
  - Save/load notebooks
```

### CI Pipeline

```yaml
name: CI
on: [push, pull_request]

jobs:
  backend-test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: goto-bus-stop/setup-zig@v2
      - run: zig build test

  frontend-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Bun
        uses: oven-sh/setup-bun@v1
      - run: cd frontend && bun install
      - run: cd frontend && bun test

  build:
    needs: [backend-test, frontend-test]
    strategy:
      matrix:
        target:
          - x86_64-linux-gnu
          - aarch64-linux-gnu
          - x86_64-macos
          - aarch64-macos
          - x86_64-windows-gnu
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: goto-bus-stop/setup-zig@v2
      - name: Setup Bun
        uses: oven-sh/setup-bun@v1
      - run: cd frontend && bun install
      - run: cd frontend && bun build
      - run: zig build -Doptimize=ReleaseFast -Dtarget=${{ matrix.target }}
```

---

## 20. Reference Materials

### Essential Reading

```
Jupyter Wire Protocol (v5.4):
https://jupyter-client.readthedocs.io/en/latest/messaging.html

Jupyter Server REST API:
https://jupyter-server.readthedocs.io/en/latest/developers/rest-api.html

Kernel Spec Format:
https://jupyter-client.readthedocs.io/en/latest/kernels.html

Notebook Format (nbformat v4):
https://nbformat.readthedocs.io/en/latest/format_description.html

ZeroMQ Guide:
https://zguide.zeromq.org/

ZeroMQ C API:
http://api.zeromq.org/
```

### Source Code to Study

```
IPyKernel (Python kernel):
https://github.com/ipython/ipykernel

Jupyter Server (Python — the thing you're replacing):
https://github.com/jupyter-server/jupyter_server

Jupyter Client (Python — protocol implementation reference):
https://github.com/jupyter/jupyter_client

JupyterLab (TypeScript frontend — the other thing you're replacing):
https://github.com/jupyterlab/jupyterlab

xeus (C++ kernel framework — inspiration):
https://github.com/jupyter-xeus/xeus
```

---

## 21. Risk Assessment & Mitigations

### Risk 1: ZeroMQ complexity
**Likelihood: Medium | Impact: High**
ZMQ has subtle behaviors (message queuing, slow joiner, etc.)
**Mitigation:** Start with simplest patterns. Test heavily. Read ZMQ guide chapters 1-3.

### Risk 2: Wire protocol edge cases
**Likelihood: High | Impact: Medium**
The Jupyter protocol has many message types and subtle behaviors.
**Mitigation:** Implement incrementally. Start with execute_request only. Add message types as needed.

### Risk 3: Cross-platform kernel spawning
**Likelihood: Medium | Impact: Medium**
Windows process management differs significantly.
**Mitigation:** Get Linux/macOS working first. Windows support in Phase 12.

### Risk 4: WebSocket + ZMQ multiplexing
**Likelihood: Medium | Impact: High**
This is the most complex component. Race conditions, deadlocks possible.
**Mitigation:** Use simple two-thread design. Test with slow/fast kernels. Add timeouts everywhere.

### Risk 5: Frontend output rendering
**Likelihood: Low | Impact: Medium**
Some kernel outputs produce unusual MIME types or malformed HTML.
**Mitigation:** Always have text/plain fallback. Sandbox HTML output. Fail gracefully.

### Risk 6: libzmq vendoring
**Likelihood: Medium | Impact: Medium**
Compiling libzmq C++ from source with Zig may have issues.
**Mitigation:** Start with dynamic linking. Move to vendoring in Phase 12.

---

## Summary Timeline

```
Phase 0:  Foundation          1-2 days
Phase 1:  Zig Server          2-3 days
Phase 2:  ZeroMQ              3-4 days
Phase 3:  Wire Protocol       3-5 days
Phase 4:  Kernel Manager      3-5 days
Phase 5:  WebSocket Bridge    4-5 days    <-- BACKEND COMPLETE
Phase 6:  REST API            2-3 days
Phase 7:  Svelte Foundation   3-4 days
Phase 8:  Editor & Cells      4-5 days
Phase 9:  Output Rendering    3-4 days
Phase 10: Multi-Kernel        2-3 days
Phase 11: Polish & UX         3-5 days    <-- V1.0 READY
Phase 12: Packaging           2-3 days
Phase 13: Advanced            Ongoing

Total to V1.0: ~8-12 weeks
```

---

*Built with Zig, Svelte, and Tailwind. Zero unnecessary overhead.*
*The fastest notebook in existence.*
