# Zenji Notebook — Development Roadmap

---

## Architecture

Zenji embeds CPython directly into the Zig server process. No ZMQ, no separate kernel processes, no inter-process communication. The kernel lives alongside the HTTP server in a single binary.

```
Browser (SvelteKit app, served as static files)
    │
    │  HTTP (REST)
    ▼
Zig Server Process
    ├── httpz HTTP server
    ├── PythonKernel (embedded CPython via translate_c)
    └── Notebook I/O (reads/writes .ipynb on disk)
```

**Execution flow:** browser sends `POST /api/execute { path, cell_id }` → server reads cell source from `.ipynb` file → kernel executes → server writes output back to file → `200 OK` → frontend re-parses file and re-renders.

The `.ipynb` file is the source of truth. The server never pushes data to the frontend unprompted.

**Multi-language:** Julia, R, and Mojo kernel stubs exist in `src/kernel/`. Only Python is implemented. Other languages will be added later — likely also as embedded runtimes rather than ZMQ subprocesses.

---

## Phases

### Phase 0 — Foundation
**Status: Complete**

- [x] Zig project, build.zig, httpz dependency
- [x] SvelteKit frontend with adapter-static
- [x] `crawler.zig` — walks `src/frontend/build/`, generates `src/assets.zig`
- [x] Frontend assets embedded in binary via `@embedFile`
- [x] Dev mode: serve assets from disk for fast iteration

### Phase 1 — HTTP Server
**Status: Complete**

- [x] httpz server with configurable port
- [x] Token auth middleware
- [x] CORS middleware (dev mode)
- [x] Request logging middleware
- [x] Static file serving (embedded + dev disk mode)
- [x] SPA fallback (unknown routes → index.html)
- [x] MIME type detection
- [x] Graceful shutdown on SIGINT/SIGTERM
- [x] CLI flags: `--port`, `--token`, `--no-auth`, `--dev`

### Phase 2 — Embedded Kernel
**Status: In progress**

- [x] CPython linked via `translate_c` + `src/c.h`
- [x] `PythonKernel` — execute cells, capture stdout/stderr/figures
- [x] `Kernel` union dispatch (`src/kernel/kernel.zig`)
- [x] Kernel starts with the server, idles until needed
- [x] Kernel shuts down cleanly on server exit
- [ ] Kernel-per-notebook (currently one global kernel)

### Phase 3 — Notebook I/O
**Status: Not started**

Read and write `.ipynb` files (nbformat v4).

- [ ] Parse `.ipynb` JSON into Zig structs
- [ ] Find a cell by ID within a notebook
- [ ] Write cell output back to `.ipynb` (stdout, stderr, display_data, error)
- [ ] Handle notebook metadata
- [ ] Handle missing/malformed notebooks gracefully
- [ ] Path traversal security (no `../` escapes from notebook root)
- [ ] `--notebook-dir` flag to set the root directory

**Notebook format reference:** https://nbformat.readthedocs.io/en/latest/format_description.html

### Phase 4 — Execute API
**Status: Not started**

The first end-to-end test: edit a cell in the frontend, click Run, see output.

- [ ] `POST /api/execute` — body: `{ "path": "...", "cell_id": "..." }`
- [ ] Read cell source from file
- [ ] Pass to `PythonKernel.execute()`
- [ ] Write output back to file (outputs array in the cell)
- [ ] Return `200 OK` with updated cell JSON
- [ ] Handle execution errors (write error output to file, still return 200)
- [ ] Handle file-not-found, cell-not-found

### Phase 5 — Contents API
**Status: Not started**

File browser — list directories, open notebooks, create/delete/rename files.

- [ ] `GET  /api/contents` — list root directory
- [ ] `GET  /api/contents/:path` — file or directory info
- [ ] `GET  /api/contents/:path?content=1` — file with content
- [ ] `PUT  /api/contents/:path` — save file
- [ ] `POST /api/contents/:path` — create file or directory
- [ ] `DELETE /api/contents/:path` — delete
- [ ] `PATCH /api/contents/:path` — rename/move
- [ ] Directory listing (name, type, last_modified)
- [ ] Notebook read (parse `.ipynb`, return as JSON)
- [ ] Text file read
- [ ] Path security

### Phase 6 — Frontend Integration
**Status: Design complete, not wired up**

The SvelteKit frontend design exists. It needs to talk to the backend.

- [ ] File browser calls `GET /api/contents`
- [ ] Opening a notebook loads from `GET /api/contents/:path?content=1`
- [ ] Run cell calls `POST /api/execute`, re-parses response
- [ ] Save calls `PUT /api/contents/:path`
- [ ] Execution count display
- [ ] Cell status indicator (idle / running)
- [ ] Output rendering: stdout, stderr, images (base64 PNG), errors
- [ ] Keyboard shortcuts: Shift+Enter (run + move), Ctrl+Enter (run + stay)

### Phase 7 — Polish
**Status: Not started**

- [ ] Autosave (debounced, every 30s if dirty)
- [ ] Ctrl+S / Cmd+S manual save
- [ ] "Run All" / "Run All Above" / "Run All Below"
- [ ] Clear outputs
- [ ] Interrupt kernel (Py_AddPendingCall + KeyboardInterrupt injection)
- [ ] Restart kernel
- [ ] Toast notifications for errors
- [ ] Handle server disconnection gracefully

### Phase 8 — Multi-Kernel
**Status: Stubs only**

- [ ] Julia kernel backend (`src/kernel/juliakernel.zig`)
- [ ] R kernel backend (`src/kernel/rkernel.zig`)
- [ ] Kernel-per-notebook (keyed by file path)
- [ ] Kernel picker in the UI
- [ ] Auto-detect kernel from notebook metadata

### Phase 9 — Packaging
**Status: Not started**

- [ ] Release build strips debug symbols
- [ ] Cross-compile: Linux x86_64, Linux aarch64, macOS x86_64, macOS aarch64, Windows x86_64
- [ ] GitHub Actions CI (build + test on push)
- [ ] Release automation (tag → build → GitHub release artifacts)
- [ ] Installation instructions

---

## Source Layout

```
src/
├── main.zig
├── c.h                  # #include <Python.h>
├── types.zig            # CellResult, Variable, Module
├── assets.zig           # generated — do not edit
│
├── server/
│   ├── server.zig       # server init, Config, startServer
│   ├── router.zig       # route registration
│   ├── handler.zig      # index handler
│   ├── static.zig       # static asset serving
│   └── middleware.zig   # logging, auth, CORS
│
├── kernel/
│   ├── kernel.zig       # Kernel union — dispatches to language backends
│   ├── pythonkernel.zig # CPython embedding (the real one)
│   ├── juliakernel.zig  # stub
│   ├── rkernel.zig      # stub
│   └── mojokernel.zig   # stub
│
├── notebook/
│   ├── format.zig       # .ipynb structs and JSON parsing
│   ├── io.zig           # read/write .ipynb files
│   └── convert.zig      # output format conversion
│
├── api/
│   ├── contents.zig     # Contents API handlers
│   ├── kernels.zig      # Kernels API handlers
│   ├── sessions.zig     # Sessions API handlers
│   ├── kernelspecs.zig  # KernelSpecs API handlers
│   └── config.zig       # Config API handler
│
├── auth/
│   └── token.zig        # token generation and validation
│
└── util/
    └── mime.zig         # MIME type detection

src/frontend/            # SvelteKit app
├── src/routes/          # pages
└── src/lib/             # components, stores, utilities
```

---

## Dev Workflow

```bash
# First time
cd src/frontend && bun install && cd ../..

# Build everything
bun run build --cwd src/frontend
zig build

# Run (development — assets served from disk)
zig build run -- --dev --no-auth

# In a second terminal, watch the frontend
cd src/frontend && bun run build --watch
```

---

## Notes

**Why not ZMQ?** The original plan used ZeroMQ to talk to external kernel processes (like Jupyter does). Direct embedding is simpler and faster — one process, no IPC, no connection files, no heartbeat threads. More importantly, this is a custom kernel: CPython is called directly through the C API (`PyRun_String`, `PyDict_*`, etc.), so IPyKernel is not involved at all. Output capture, figure handling, and variable inspection are all implemented in Zig.

**Why not WebSockets?** The execution model is request/response — the browser sends code, the server runs it and updates the file, the browser re-reads. WebSockets would add complexity without a clear benefit at this stage.

**CPython is temporary-ish.** The embedding approach works well for Python. For Julia and R, the plan is either similar embedding or spawning the runtime and communicating over a simple pipe — not ZMQ.
