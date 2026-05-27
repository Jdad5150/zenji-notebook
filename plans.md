# Zenji Notebook — Development Roadmap

_v0.5.0_

---

## Architecture

The Python kernel runs as a persistent subprocess. `worker.py` is embedded in the binary at compile time, written to `/tmp` on first kernel start, and kept alive between cell executions so variables persist across cells. Communication is JSON over stdin/stdout — one command line in, one response line back.

```
Browser (SvelteKit app, served as static files)
    │
    │  HTTP (REST)
    ▼
Zig Server Process
    ├── httpz HTTP server
    ├── PythonKernel ──► worker.py subprocess  (stdin/stdout JSON)
    └── Notebook I/O (reads/writes .znb on disk)
```

**Execution flow:** browser sends `POST /api/execute { path, cell_id }` → server reads cell source from `.znb` → sends JSON command to worker stdin → reads JSON response from worker stdout → writes text outputs inline to `.znb`, saves figures to sidecar → returns updated cell as JSON.

The `.znb` file is the source of truth. The server never pushes data to the frontend unprompted.

**Single notebook (V1):** Only one notebook is open at a time. The single global kernel serves whichever notebook is currently loaded. Multiple notebooks can be run simultaneously by launching multiple server instances on different ports.

**Environment selection:** On first launch (or when no `.zenji.json` exists), the frontend shows the environment picker. Zenji scans the notebook directory for Python venvs and system Pythons, the user picks one, and the selection is saved to `.zenji.json` in the workspace root. On subsequent starts the saved kernel is spawned automatically.

**Multi-language:** Julia, R, and Mojo kernel stubs exist in `src/kernel/`. Only Python is implemented.

---

## .znb Format

`.znb` is Zenji's native binary notebook format. It is compact, fixed-layout, and directly mappable to Zig structs. Image and rich outputs are **not** stored in the file — they live in a sidecar directory `.{notebook_name}/` next to the `.znb` file. The `.znb` stores only a path reference (`image_ref`) pointing into the sidecar.

**On-disk layout:**

```
my_analysis.znb          — source of truth: code, structure, text outputs
.my_analysis/            — execution cache: image/rich output artifacts
    {cell_id}/
        0.png
        1.png
        ...
```

The sidecar is ephemeral. If an artifact is missing, the frontend skips it. `rm -rf .my_analysis/` clears all figure outputs; re-running cells recreates them.

**Binary format:**

```
[NOTEBOOK HEADER]
magic:         u8[5]   "ZENJI"
version:       u8      (currently 1)
cell_count:    u32
next_cell_id:  u32     monotonic counter — never reused, ensures stable sidecar paths
kernel_type:   u8      0=python, 1=julia, 2=r, 3=mojo

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

Text outputs (stdout, stderr, error tracebacks) are stored inline. Binary outputs (images) are stored as a path reference pointing into the sidecar directory.

---

## Phases

### Phase 0 — Foundation
*v0.1.0 — Complete*

- [x] Zig project, build.zig, httpz dependency
- [x] SvelteKit frontend with adapter-static
- [x] `crawler.zig` — walks `src/frontend/build/`, generates `src/assets.zig`
- [x] Frontend assets embedded in binary via `@embedFile`
- [x] Dev mode: serve assets from disk for fast iteration

### Phase 1 — HTTP Server
*v0.2.0 — Complete*

- [x] httpz server with configurable port
- [x] Token auth middleware
- [x] CORS middleware (dev mode)
- [x] Request logging middleware
- [x] Static file serving (embedded + dev disk mode)
- [x] SPA fallback (unknown routes → index.html)
- [x] MIME type detection
- [x] Graceful shutdown on SIGINT/SIGTERM
- [x] CLI flags: `--port`, `--token`, `--no-auth`, `--dev`, `--root`

### Phase 2 — Python Kernel
*v0.3.0 — Complete*

Switched from embedded CPython (translate_c) to a subprocess worker. `worker.py` is embedded at compile time via `@embedFile` and written to `/tmp/.zenji_worker.py` on first kernel start. Commands are JSON lines on stdin; responses are JSON lines on stdout. Variables persist across cells because the worker stays alive between requests.

- [x] `worker.py` — persistent Python process, JSON protocol, stdout/stderr capture, matplotlib figure capture
- [x] `PythonKernel` — spawn worker, send/receive JSON, parse results
- [x] `Kernel` union dispatch (`src/kernel/kernel.zig`)
- [x] Environment scanner (`src/env/scanner.zig`) — detects venvs in notebook directory
- [x] Environment config (`src/env/config.zig`) — persists selection to `.zenji.json`
- [x] `GET /api/environment` — return detected + saved environments for a directory
- [x] `POST /api/environment` — save selection and (re)start kernel
- [x] `GET /api/home` — return user home directory for the directory browser
- [x] Environment picker UI (`EnvironmentPicker.svelte`) — shown on first launch
- [x] Kernel shuts down cleanly on server exit

### Phase 3 — .znb Format & I/O
*v0.4.0 — Complete*

- [x] `output.zig`, `cell.zig`, `notebook.zig` — in-memory structs with serialize/deserialize
- [x] Find a cell by ID (`findCell`)
- [x] `load()` / `save()` confirmed working with real files (Zig 0.16.0 Io API)
- [x] Write updated cell output back to disk (load → findCell → mutate → save)
- [x] Handle missing/malformed `.znb` gracefully (file-not-found, invalid magic, bad version)
- [x] Path traversal security (`util/path.zig` — rejects `..` and absolute paths)

### Phase 4 — Execute API
*v0.5.0 — Complete*

End-to-end execution: edit a cell, click Run, see output and figures.

- [x] `POST /api/execute` — body: `{ "path": "...", "cell_id": <u32> }`
- [x] Read cell source from `.znb`
- [x] Pass to `PythonKernel.execute()`
- [x] Write text outputs (stdout/stderr) inline to `.znb`; increment `execution_count`
- [x] Write figure artifacts to sidecar directory (`createDirPath` + `writeFile`)
- [x] Return `200 OK` with updated cell JSON (id, type, execution_count, source, outputs)
- [x] Handle execution errors — write error output, still return 200
- [x] Handle file-not-found, cell-not-found
- [x] `GET /outputs?path=<notebook>&ref=<cell_id/fig_idx>` — serve sidecar PNG to browser

### Phase 5 — Frontend Integration
*v0.6.0 — In Progress*

- [x] Open a `.znb` — `GET /api/notebook?path=...` returns full notebook as JSON
- [x] Run cell calls `POST /api/execute`, re-renders updated cell from response
- [x] Save calls `PUT /api/notebook?path=...`
- [x] Image outputs rendered via `<img src="/outputs?path=...&ref=...">` (sidecar route)
- [x] Plot lightbox — click thumbnail in sidebar or inline plot to open fullscreen viewer with keyboard navigation
- [x] Left sidebar shows real directory contents from `GET /api/contents`
- [x] Variable explorer — live kernel namespace displayed after each execution
- [x] Module listing in variable explorer
- [ ] Execution count display (`[3]:`)
- [ ] Cell status indicator (idle / running)
- [ ] Keyboard shortcuts: Shift+Enter (run + move down), Ctrl+Enter (run + stay)
- [ ] Wire up menu bar actions (Run All, Save, Export)

### Phase 6 — Contents API
*v0.7.0 — Not started*

Full file management: create, rename, delete notebooks from the UI.

- [x] `GET /api/contents?path=` — directory listing (name, type, size)
- [ ] `--new <name>` CLI flag to create a blank `.znb`
- [ ] `POST /api/contents/:path` — create new `.znb`
- [ ] `DELETE /api/contents/:path` — delete `.znb` + sidecar
- [ ] `PATCH /api/contents/:path` — rename/move (moves sidecar too)

### Phase 7 — Polish
*v0.8.0 — Not started*

- [ ] Autosave (debounced, 30s if dirty)
- [ ] Ctrl+S / Cmd+S manual save
- [ ] "Run All" / "Run All Above" / "Run All Below"
- [ ] Clear outputs (deletes sidecar dir, zeroes output_count on all cells)
- [ ] Interrupt kernel (send signal to worker subprocess)
- [ ] Restart kernel (kill and respawn worker)
- [ ] Toast notifications for errors
- [ ] Handle server disconnection gracefully

### Phase 8 — .ipynb Interop
*v0.9.0 — Not started*

Import existing Jupyter notebooks; export `.znb` back to `.ipynb` for sharing.

- [ ] `notebook/ipynb.zig` — parse `.ipynb` JSON (nbformat v4) into in-memory `Notebook`
- [ ] `notebook/convert.zig` — `Notebook` ↔ `.znb` and `Notebook` ↔ `.ipynb`
- [ ] `POST /api/import` — upload or path-reference a `.ipynb`, convert to `.znb`
- [ ] `GET /api/export?path=...&format=ipynb` — convert `.znb` to `.ipynb` for download
- [ ] Handle nbformat v3/v4 variance gracefully
- [ ] Handle the `source` as string-or-array-of-strings quirk
- [ ] Strip image outputs from `.ipynb` import (require re-run to populate sidecar)

**Reference:** https://nbformat.readthedocs.io/en/latest/format_description.html

### Phase 9 — Multi-Kernel
*v0.10.0 — Stubs only*

- [ ] Julia kernel backend (`src/kernel/juliakernel.zig`)
- [ ] R kernel backend (`src/kernel/rkernel.zig`)
- [ ] Kernel picker in the UI
- [ ] Auto-detect kernel from notebook metadata
- [ ] Kernel-per-notebook (keyed by file path, for running multiple notebooks)

### Phase 10 — Packaging
*v1.0.0 — Not started*

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
├── types.zig                # CellResult, Variable, Module
├── assets.zig               # generated — do not edit
│
├── server/
│   ├── server.zig           # server init, Config, startServer
│   ├── router.zig           # route registration
│   ├── handler.zig          # route handlers
│   ├── static.zig           # static asset serving
│   └── middleware.zig       # logging, auth, CORS
│
├── kernel/
│   ├── kernel.zig           # Kernel union — dispatches to language backends
│   ├── pythonkernel.zig     # subprocess worker backend
│   ├── worker.py            # embedded Python worker (JSON protocol over stdin/stdout)
│   ├── juliakernel.zig      # stub
│   ├── rkernel.zig          # stub
│   └── mojokernel.zig       # stub
│
├── notebook/
│   ├── notebook.zig         # Notebook — load/save/serialize/deserialize/findCell
│   ├── cell.zig             # Cell — serialize/deserialize
│   └── output.zig           # Output — serialize/deserialize
│
├── env/
│   ├── scanner.zig          # detect Python venvs in a directory
│   └── config.zig           # read/write .zenji.json
│
├── api/
│   ├── execute.zig          # POST /api/execute
│   ├── outputs.zig          # GET /outputs (sidecar image serving)
│   ├── environment.zig      # GET/POST /api/environment, GET /api/home
│   ├── notebook.zig         # GET/PUT /api/notebook
│   ├── contents.zig         # GET /api/contents (directory listing)
│   ├── variables.zig        # GET /api/variables (kernel namespace)
│   └── (stubs: config, kernels, kernelspecs, sessions)
│
├── auth/
│   └── token.zig            # token generation and validation
│
└── util/
    ├── mime.zig             # MIME type detection
    ├── path.zig             # sandbox path validation
    └── test_io.zig          # FixedBufferStream for tests

src/frontend/                # SvelteKit app (Bun + Tailwind CSS 4 + CodeMirror 6)
├── src/routes/              # pages (+page.svelte for /, /notebook)
└── src/lib/components/      # NotebookCell, DataExplorer, EnvironmentPicker,
                             # PlotLightbox, DirectoryBrowser, NotebookSidebar, …
```

---

## Dev Workflow

```bash
# First time
cd src/frontend && bun install && cd ../..

# Build everything
bun run build --cwd src/frontend
zig build

# Run (development — assets served from disk, no auth)
zig build run -- --dev --no-auth

# In a second terminal, watch the frontend
cd src/frontend && bun run dev
```

---

## Notes

**Why not ZMQ?** The original plan used ZeroMQ to talk to external kernel processes (like Jupyter does). A subprocess communicating over stdin/stdout is simpler — no IPC sockets, no connection files, no heartbeat threads. The worker protocol is a single JSON line per command/response, which is trivial to debug with `strace` or by hand.

**Why not embedded CPython?** The initial implementation used Zig's `translate_c` to call CPython directly. That works but requires matching Python header versions at compile time and makes the binary dependent on a specific libpython. The subprocess approach works with any Python installation — system Python, pyenv, conda, uv, whatever — and the user can switch environments without recompiling.

**Why not WebSockets?** The execution model is request/response — the browser sends code, the server runs it, the browser re-renders from the response. WebSockets would add complexity without a clear benefit at this stage.

**Why .znb and not .ipynb?** The `.ipynb` JSON format is verbose, stores binary outputs as base64, and requires parsing the entire document to access a single cell. `.znb` is a compact binary format; image artifacts live in a sidecar directory and are served directly as static files. `.ipynb` import/export is planned for interoperability (Phase 8).

**Why sidecar for images?** Keeping image artifacts out of the `.znb` file means the notebook stays small regardless of how many figures it produces. The sidecar is an execution cache: delete it to clear all figure outputs, lose it and just re-run the cells. Crucially, figures survive server restarts — re-opening a notebook shows the last run's plots without re-executing anything.
