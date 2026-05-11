# Zenji Notebook

_v0.4.0_

A notebook server in a single binary. Zig backend, embedded CPython, SvelteKit frontend. No ZMQ, no IPyKernel, no 500MB of dependencies.

## Why

JupyterLab works, but the stack is enormous — Tornado, ZMQ, a TypeScript monorepo. For local notebook work you shouldn't need all of that.

Zenji replaces the server and the kernel. CPython is embedded directly via the C API. Output capture, figure handling, and variable inspection are all in Zig. The `.znb` binary notebook format is compact, fast to load, and keeps image artifacts in a sidecar directory.

## Status

Evolving. Core loop works: open a `.znb`, edit cells, execute them, see output and variables.

**What works:**
- HTTP server with token auth, CORS (dev mode), and static file serving
- SvelteKit frontend embedded in the binary at build time
- CPython kernel: execute cells (stdout/stderr/figure capture), variable inspection, module listing
- `.znb` binary notebook format — full load/save/serialize/deserialize with round-trip tests
- `GET /api/notebook` — load full notebook as JSON
- `PUT /api/notebook` — save structural changes (add/delete/move cells)
- `POST /api/execute` — run a cell, write output back to `.znb`
- `GET /api/contents` — directory listing for the file browser
- `GET /api/variables` — live kernel namespace for the variable explorer
- Live variable explorer in the frontend (updates after each cell execution)
- Cell add/delete/move/reorder in the editor

**What's next:**
- Plot rendering pipeline (save figures to sidecar, serve as static files, display inline)
- Wire the sidebar file tree (currently hardcoded)
- Wire the menu bar actions (Run All, Save, Export, kernel management)
- Sessions/kernels/config/checkpoints/terminals APIs (routes registered, return 501)
- `.ipynb` import/export
- Julia/R/Mojo kernel backends

## Requirements

- [Zig](https://ziglang.org/) 0.16.0
- [Bun](https://bun.sh/) 1.x (for the SvelteKit frontend)
- Python 3.14 with development headers (`python3-dev` on Ubuntu/Debian)

```bash
# Ubuntu/Debian
sudo apt install python3-dev

# macOS (via Homebrew)
brew install python3
```

## Building

```bash
# 1. Install frontend dependencies
cd src/frontend
bun install
cd ../..

# 2. Build the frontend
bun run build --cwd src/frontend

# 3. Build the server (also generates src/assets.zig from the frontend build)
zig build

# 4. Run tests
zig build test
```

The output binary is at `zig-out/bin/zenji_notebook`.

## Running

```bash
# Start with a random auth token (printed to stdout)
./zig-out/bin/zenji_notebook

# Development mode: no auth, assets from disk, creates example.znb
zig build run -- --dev --no-auth

# Custom port
./zig-out/bin/zenji_notebook --port 9999
```

## Architecture

The server is a single Zig binary. At build time, `crawler.zig` walks `src/frontend/build/` and generates `src/assets.zig` — a file full of `@embedFile` calls that bake every frontend asset into the binary.

CPython is embedded via Zig's `translate_c`. The kernel lives in the same process as the HTTP server. When a user runs a cell, the server reads the cell source from the `.znb` file, passes it to the embedded kernel, writes the output back to the file, and returns the updated cell as JSON. The frontend re-fetches the full notebook to stay in sync.

```
Browser (SvelteKit)
    │
    │  HTTP REST
    ▼
Zig Server Process
    ├── httpz HTTP server
    ├── PythonKernel (embedded CPython)
    └── Notebook I/O (reads/writes .znb on disk)
```

## .znb Format

Zenji uses `.znb`, a custom binary notebook format. It is compact, fixed-layout, and directly mappable to Zig structs. Image outputs are stored in a sidecar directory `.{notebook_name}/` — the `.znb` stores only path references.

See [plans.md](plans.md) for the full binary layout specification.

## Project Structure

```
zenji-notebook/
├── build.zig            # build script — CPython linking, asset embedding, test step
├── build.zig.zon        # dependencies (httpz)
├── crawler.zig          # generates src/assets.zig from src/frontend/build/
├── plans.md             # full development roadmap
├── src/
│   ├── main.zig         # CLI args, server startup
│   ├── c.h              # thin wrapper: #include <Python.h>
│   ├── types.zig        # CellResult, Variable, Module
│   ├── test_all.zig     # test entry point
│   ├── server/          # HTTP server, routing, middleware, static serving
│   ├── kernel/          # Kernel union + language backends (Python implemented)
│   ├── notebook/        # .znb binary format: notebook, cell, output
│   ├── api/             # REST handlers (execute, notebook, contents, variables)
│   ├── auth/            # token generation and validation
│   └── util/            # MIME detection, path validation, test helpers
└── src/frontend/        # SvelteKit app (bun + Tailwind CSS 4 + CodeMirror 6)
```

## License

MIT
