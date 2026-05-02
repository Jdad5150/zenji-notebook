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
    └── Notebook I/O (reads/writes .znb on disk)
```

**Execution flow:** browser sends `POST /api/execute { path, cell_id }` → server reads cell source from `.znb` file → kernel executes → server writes output back to file → `200 OK` → frontend re-renders from response.

The `.znb` file is the source of truth. The server never pushes data to the frontend unprompted.

**Single notebook (V1):** Only one notebook is open at a time. The single global kernel serves whichever notebook is currently loaded. Multiple notebooks can be run simultaneously by launching multiple server instances on different ports.

**Multi-language:** Julia, R, and Mojo kernel stubs exist in `src/kernel/`. Only Python is implemented. Other languages will be added later — likely also as embedded runtimes rather than ZMQ subprocesses.

---

## .znb Format

`.znb` is Zenji's native binary notebook format. It is compact, fixed-layout, and directly mappable to Zig structs. Image and rich outputs are **not** stored in the file — they live in a sidecar directory `.{notebook_name}/` next to the `.znb` file. The `.znb` stores only a reference (the cell ID + output index) that the frontend uses to fetch the artifact via a static file route.

**On-disk layout:**

```
my_analysis.znb          — source of truth: code, structure, text outputs
.my_analysis/            — execution cache: image/rich output artifacts
    {cell_id}/
        0.png
        1.png
        ...
```

The sidecar directory is ephemeral. If an artifact is missing, the frontend skips it and marks the output as stale — a re-run recreates it. Clearing all outputs is `rm -rf .my_analysis/`.

**Binary format:**

```
[NOTEBOOK HEADER]
magic:         u8[5]   "ZENJI"
version:       u8      (currently 1)
cell_count:    u32
next_cell_id:  u32     monotonic counter — never reused, ensures stable sidecar paths

[CELL]  × cell_count
cell_type:         u8      0=code, 1=markdown
cell_id:           u32     stable, assigned at creation
execution_count:   u32     0 = never executed
source_len:        u32
source:            u8[source_len]   raw UTF-8
output_count:      u8      (most cells have 0–3 outputs)

  [OUTPUT]  × output_count
  output_type:   u8      0=stdout, 1=stderr, 2=image_ref, 3=error
  output_len:    u32
  output:        u8[output_len]
                   stdout/stderr/error → raw UTF-8 text
                   image_ref → "{cell_id}/{index}" path fragment into sidecar dir
```

Text outputs (stdout, stderr, error tracebacks) are stored inline. Binary outputs (images, rich data) are stored as a path reference pointing into the sidecar directory.

---

## Phases

### Phase 0 — Foundation
*v0.1.0*

**Status: Complete**

- [x] Zig project, build.zig, httpz dependency
- [x] SvelteKit frontend with adapter-static
- [x] `crawler.zig` — walks `src/frontend/build/`, generates `src/assets.zig`
- [x] Frontend assets embedded in binary via `@embedFile`
- [x] Dev mode: serve assets from disk for fast iteration

### Phase 1 — HTTP Server
*v0.2.0*

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
*v0.3.0*

**Status: Complete**

- [x] CPython linked via `translate_c` + `src/c.h`
- [x] `PythonKernel` — execute cells, capture stdout/stderr/figures
- [x] `Kernel` union dispatch (`src/kernel/kernel.zig`)
- [x] Kernel starts with the server, idles until needed
- [x] Kernel shuts down cleanly on server exit

### Phase 3 — .znb Format & I/O
*v0.4.0*

**Status: Complete**

Implement the native binary format. Goal: read a `.znb` from disk, find a cell, write output back.

- [x] `output.zig`, `cell.zig`, `notebook.zig` — in-memory structs with serialize/deserialize
- [x] Find a cell by ID (`findCell`)
- [x] `load()` / `save()` confirmed working with real files (0.16.0 write API)
- [x] Write updated cell output back to disk (load → findCell → mutate → save)
- [x] Handle missing/malformed `.znb` gracefully (file-not-found, invalid magic, bad version)
- [x] Path traversal security (`util/path.zig` — rejects `..` and absolute paths)

### Phase 4 — Execute API
*v0.5.0*

**Status: Not started**

The first end-to-end test: edit a cell in the frontend, click Run, see output.

- [ ] `POST /api/execute` — body: `{ "path": "...", "cell_id": "..." }`
- [ ] Read cell source from `.znb`
- [ ] Pass to `PythonKernel.execute()`
- [ ] Write text output inline to `.znb`; increment `execution_count`
- [ ] Write image artifacts to sidecar directory (create dir on first write)
- [ ] Return `200 OK` with updated cell JSON
- [ ] Handle execution errors (write error output, still return 200)
- [ ] Handle file-not-found, cell-not-found
- [ ] Serve sidecar artifacts: `GET /outputs/:notebook/:cell_id/:index`

### Phase 5 — Frontend Integration
*0.6.0*

**Status: Design complete, not wired up**

The SvelteKit frontend design exists. It needs to talk to the backend.

- [ ] Open a `.znb` — `GET /api/notebook?path=...` returns full notebook as JSON
- [ ] Run cell calls `POST /api/execute`, re-renders updated cell from response
- [ ] Save calls `PUT /api/notebook?path=...`
- [ ] Image outputs rendered via `<img src="/outputs/...">` (sidecar route)
- [ ] Execution count display (`[3]:`)
- [ ] Cell status indicator (idle / running)
- [ ] Output rendering: stdout, stderr, images, errors
- [ ] Keyboard shortcuts: Shift+Enter (run + move), Ctrl+Enter (run + stay)

### Phase 6 — Contents API
*v0.7.0*

**Status: Not started**

File browser — list directories, open and manage notebooks.

- [ ] `--notebook-dir` flag to set the root directory
- [ ] `--new <name>` CLI flag to create a blank `.znb`
- [ ] `GET  /api/contents` — list root directory (`.znb` files + subdirs)
- [ ] `GET  /api/contents/:path` — file or directory info
- [ ] `POST /api/contents/:path` — create new `.znb`
- [ ] `DELETE /api/contents/:path` — delete `.znb` + sidecar
- [ ] `PATCH /api/contents/:path` — rename/move (moves sidecar too)
- [ ] Directory listing (name, type, last_modified, size)
- [ ] Path security

### Phase 7 — Polish
*v0.8.0*

**Status: Not started**

- [ ] Autosave (debounced, 30s if dirty)
- [ ] Ctrl+S / Cmd+S manual save
- [ ] "Run All" / "Run All Above" / "Run All Below"
- [ ] Clear outputs (deletes sidecar dir, zeroes output_count on all cells)
- [ ] Interrupt kernel (`Py_AddPendingCall` + KeyboardInterrupt injection)
- [ ] Restart kernel
- [ ] Toast notifications for errors
- [ ] Handle server disconnection gracefully

### Phase 8 — .ipynb Interop
*v0.9.0*

**Status: Not started**

Import existing Jupyter notebooks; export `.znb` back to `.ipynb` for sharing.

- [ ] `notebook/ipynb.zig` — parse `.ipynb` JSON (nbformat v4) into in-memory `Notebook`
- [ ] `notebook/convert.zig` — `Notebook` ↔ `.znb` and `Notebook` ↔ `.ipynb`
- [ ] `POST /api/import` — upload or path-reference a `.ipynb`, convert to `.znb`
- [ ] `GET  /api/export?path=...&format=ipynb` — convert `.znb` to `.ipynb` for download
- [ ] Handle nbformat v3/v4 variance gracefully
- [ ] Handle the `source` as string-or-array-of-strings quirk
- [ ] Strip image outputs from `.ipynb` import (require re-run to populate sidecar)

**Reference:** https://nbformat.readthedocs.io/en/latest/format_description.html

### Phase 9 — Multi-Kernel
*v0.10.0* 

**Status: Stubs only**

- [ ] Julia kernel backend (`src/kernel/juliakernel.zig`)
- [ ] R kernel backend (`src/kernel/rkernel.zig`)
- [ ] Kernel picker in the UI
- [ ] Auto-detect kernel from notebook metadata
- [ ] Kernel-per-notebook (keyed by file path, for running multiple notebooks)

### Phase 10 — Packaging
*v1.0.0*

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
├── c.h                      # #include <Python.h>
├── types.zig                # CellResult, Variable, Module
├── assets.zig               # generated — do not edit
│
├── server/
│   ├── server.zig           # server init, Config, startServer
│   ├── router.zig           # route registration
│   ├── handler.zig          # index handler
│   ├── static.zig           # static asset serving
│   └── middleware.zig       # logging, auth, CORS
│
├── kernel/
│   ├── kernel.zig           # Kernel union — dispatches to language backends
│   ├── pythonkernel.zig     # CPython embedding (the real one)
│   ├── juliakernel.zig      # stub
│   ├── rkernel.zig          # stub
│   └── mojokernel.zig       # stub
│
├── notebook/
│   ├── notebook.zig         # Notebook — load/save/serialize/deserialize/findCell
│   ├── cell.zig             # Cell — serialize/deserialize
│   └── output.zig           # Output — serialize/deserialize
│
├── api/                     # HTTP handler stubs (Phase 4+)
│   ├── config.zig           # stub
│   ├── contents.zig         # stub — Contents API (Phase 6)
│   ├── kernels.zig          # stub
│   ├── kernelspecs.zig      # stub
│   └── sessions.zig         # stub
│
├── auth/
│   ├── token.zig            # token generation and validation
│   └── cookie.zig           # stub
│
└── util/
    ├── json.zig             # stub
    ├── logging.zig          # stub
    ├── mime.zig             # MIME type detection
    ├── path.zig             # sandbox path validation
    ├── platform.zig         # stub
    ├── test_io.zig          # FixedBufferStream for tests
    └── uuid.zig             # stub

src/frontend/                # SvelteKit app
├── src/routes/              # pages
└── src/lib/                 # components, stores, utilities
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
cd src/frontend && bun run dev
```

---

## Notes

**Why not ZMQ?** The original plan used ZeroMQ to talk to external kernel processes (like Jupyter does). Direct embedding is simpler and faster — one process, no IPC, no connection files, no heartbeat threads. More importantly, this is a custom kernel: CPython is called directly through the C API (`PyRun_String`, `PyDict_*`, etc.), so IPyKernel is not involved at all. Output capture, figure handling, and variable inspection are all implemented in Zig.

**Why not WebSockets?** The execution model is request/response — the browser sends code, the server runs it, the browser re-renders from the response. WebSockets would add complexity without a clear benefit at this stage.

**Why .znb and not .ipynb?** The `.ipynb` JSON format is verbose, stores binary outputs as base64, and requires parsing the entire document to access a single cell. `.znb` is a compact binary format with a cell offset table, direct binary output storage, and a sidecar directory for image artifacts. Notebooks are used for EDA and presentation — not as version-controlled source of truth — so diffability is not a meaningful concern. `.ipynb` import/export is supported for interoperability.

**Why sidecar for images?** Keeping image artifacts out of the `.znb` file means the notebook file stays small regardless of how many figures a notebook produces. The sidecar is an execution cache: delete it to clear all outputs, lose it and just re-run the cells.

**CPython is temporary-ish.** The embedding approach works well for Python. For Julia and R, the plan is either similar embedding or spawning the runtime and communicating over a simple pipe — not ZMQ.
