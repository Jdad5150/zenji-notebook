# Zenji Notebook

_v0.5.0_

A notebook server in a single binary. Zig backend, subprocess Python kernel, SvelteKit frontend. No ZMQ, no IPyKernel, no 500MB of dependencies.

## Why

JupyterLab works, but the stack is enormous — Tornado, ZMQ, a TypeScript monorepo. For local notebook work you shouldn't need all of that.

Zenji is a single self-contained binary that serves the frontend, runs Python cells, and stores notebooks in a compact binary format. The Python kernel runs as a persistent subprocess worker communicating over stdin/stdout JSON — no embedding, no C headers, any venv works.

## Status

Core loop is working end to end: open a `.znb`, select a Python environment, edit cells, run them, see output and plots inline, inspect variables in the sidebar.

**What works:**
- HTTP server with token auth, CORS (dev mode), and static file serving
- SvelteKit frontend embedded in the binary at build time
- Python kernel — persistent subprocess worker (`worker.py`), any venv or system Python
- Environment picker — scans the notebook directory for venvs, saves selection to `.zenji.json`
- `.znb` binary notebook format — full load/save/serialize/deserialize with round-trip tests
- `POST /api/execute` — run a cell, write text output back to `.znb`, save figures to sidecar
- `GET /outputs` — serve sidecar PNG artifacts to the browser
- `GET /api/notebook` / `PUT /api/notebook` — load and save notebook structure
- `GET /api/contents` — directory listing for the file browser sidebar
- `GET /api/variables` — live kernel namespace (variables + imported modules)
- Plot pipeline — figures saved as `.png` files in the sidecar, rendered inline in the cell
- Plot lightbox — click any thumbnail in the sidebar to open a fullscreen viewer
- Live variable and module explorer (updates after each cell run)
- Cell add / delete / move / reorder
- Real directory listing in the left sidebar

**What's next:**
- Execution count display (`[3]:`)
- Cell status indicator (idle / running)
- Keyboard shortcuts (Shift+Enter, Ctrl+Enter)
- Wire up menu bar actions (Run All, Save, Export)
- `.ipynb` import/export
- Julia / R / Mojo kernel backends

## Requirements

- [Zig](https://ziglang.org/) 0.16.0
- [Bun](https://bun.sh/) 1.x (for the SvelteKit frontend)
- Python 3.x — any version, any venv (system Python works fine)

No Python development headers required.

## Building

```bash
# 1. Install frontend dependencies
cd src/frontend
bun install
cd ../..

# 2. Build the frontend
bun run build --cwd src/frontend

# 3. Build the server
zig build

# 4. Run tests
zig build test
```

Output binary: `zig-out/bin/zenji_notebook`

## Running

```bash
# Start with a random auth token (printed to stdout as a clickable URL)
./zig-out/bin/zenji_notebook

# Development mode: no auth, assets served from disk, creates example.znb
zig build run -- --dev --no-auth

# Custom port
./zig-out/bin/zenji_notebook --port 9999

# Serve notebooks from a specific directory
./zig-out/bin/zenji_notebook --root /path/to/notebooks
```

On first launch, open the printed URL and select a Python environment. The selection is saved to `.zenji.json` in the workspace root and reused on subsequent starts.

## Architecture

```
Browser (SvelteKit)
    │
    │  HTTP REST
    ▼
Zig Server Process
    ├── httpz HTTP server
    ├── PythonKernel ──► worker.py subprocess (stdin/stdout JSON)
    └── Notebook I/O (reads/writes .znb on disk)
```

The server is a single Zig binary. At build time, `crawler.zig` walks `src/frontend/build/` and generates `src/assets.zig` — every frontend asset baked in via `@embedFile`. `worker.py` is also embedded at compile time and written to `/tmp` on first kernel start.

When a user runs a cell, the server reads the source from `.znb`, sends it to the worker over stdin as a JSON command, receives the result (stdout, stderr, base64 figures) over stdout, writes text outputs inline to `.znb`, decodes and saves figures to the sidecar directory, and returns the updated cell as JSON.

## .znb Format

Zenji uses `.znb`, a compact binary notebook format. Image outputs are stored in a sidecar directory `.{notebook_name}/` — the `.znb` stores only path references.

```
my_analysis.znb       — source of truth: code, structure, text outputs
.my_analysis/         — execution cache: image artifacts
    {cell_id}/
        0.png
        1.png
```

The sidecar is ephemeral. `rm -rf .my_analysis/` clears all figure outputs; re-running the cells recreates them.

See [plans.md](plans.md) for the full binary layout specification.

## Project Structure

```
zenji-notebook/
├── build.zig            # build script — asset embedding, test step
├── build.zig.zon        # dependencies (httpz)
├── crawler.zig          # generates src/assets.zig from src/frontend/build/
├── plans.md             # full development roadmap and .znb format spec
├── src/
│   ├── main.zig         # CLI args, server startup
│   ├── types.zig        # CellResult, Variable, Module
│   ├── server/          # HTTP server, routing, middleware, static serving
│   ├── kernel/          # Kernel union + language backends
│   │   ├── kernel.zig
│   │   ├── pythonkernel.zig   # subprocess worker backend
│   │   ├── worker.py          # embedded Python worker script
│   │   └── (julia/r/mojo stubs)
│   ├── notebook/        # .znb binary format: notebook, cell, output
│   ├── env/             # Python venv scanner + .zenji.json config
│   ├── api/             # REST handlers
│   │   ├── execute.zig        # POST /api/execute
│   │   ├── outputs.zig        # GET /outputs (sidecar images)
│   │   ├── environment.zig    # GET/POST /api/environment, GET /api/home
│   │   ├── notebook.zig       # GET/PUT /api/notebook
│   │   ├── contents.zig       # GET /api/contents
│   │   └── variables.zig      # GET /api/variables
│   ├── auth/            # token generation and validation
│   └── util/            # MIME detection, path validation, test helpers
└── src/frontend/        # SvelteKit app (Bun + Tailwind CSS 4 + CodeMirror 6)
```

## License

MIT
