# Zenji Notebook

_v0.4.0_

A Jupyter-compatible notebook server written in Zig with a Svelte frontend. Ships as a single binary. No Python server, no Node runtime, no 500MB of dependencies.

## Why

JupyterLab works, but it's slow to start, heavy to install, and the stack is enormous — Tornado, ZMQ, a TypeScript monorepo the size of a small operating system. For local notebook work you shouldn't need all of that.

Zenji replaces the server, the frontend, and the kernel. CPython is embedded directly via the C API — no IPyKernel, no ZMQ, no kernel processes. Output capture, figure handling, and variable inspection are implemented in Zig.

## Status

Early development. This is not ready for daily use yet.

What works:

- HTTP server with token auth and dev/prod static file serving
- SvelteKit frontend embedded in the binary at build time
- CPython embedded directly — kernel starts with the server, idles until needed

What's next:

- Notebook file I/O (reading/writing `.ipynb`)
- `POST /api/execute` — run a cell, write output back to the file
- File browser API
- Wire up the frontend to the execution API

## Requirements

- [Zig](https://ziglang.org/) 0.16.0
- [Bun](https://bun.sh/) 1.x (to build the frontend)
- Python 3.12 with development headers (`python3-dev` on Ubuntu/Debian)

```bash
# Ubuntu/Debian
sudo apt install python3-dev

# macOS (via Homebrew)
brew install python3
```

## Building

```bash
# 1. Build the frontend
cd src/frontend
bun install
bun run build
cd ../..

# 2. Build the server (also generates src/assets.zig from the frontend build)
zig build
```

The output binary is at `zig-out/bin/zenji_notebook`.

## Running

```bash
# Start with a random auth token (printed to stdout)
./zig-out/bin/zenji_notebook

# Skip auth (local development)
./zig-out/bin/zenji_notebook --no-auth

# Custom port
./zig-out/bin/zenji_notebook --port 9999

# Dev mode: serves frontend assets from disk instead of the embedded bundle.
# Run `bun run build --watch` in src/frontend/ alongside this.
./zig-out/bin/zenji_notebook --dev --no-auth

# Or use `zig build run` for the full build + run cycle
zig build run -- --no-auth
```

## Architecture

The server is a single Zig binary. At build time, `crawler.zig` walks `src/frontend/build/` and generates `src/assets.zig` — a file full of `@embedFile` calls that bake every frontend asset into the binary. No CDN, no separate static server.

CPython is embedded via Zig's `translate_c` — the kernel lives in the same process as the HTTP server. When a user runs a cell, the server reads the cell source from the `.ipynb` file, passes it to the embedded kernel, writes the output back to the file, and returns 200. The frontend re-parses the file on each response.

```
Browser
  └── GET  /                    → index.html (embedded in binary)
  └── GET  /_app/...            → JS/CSS bundles (embedded in binary)
  └── POST /api/execute         → kernel runs cell, updates .ipynb, returns 200
  └── GET  /api/contents/...    → directory listing / file contents

Zig Server Process
  ├── httpz HTTP server
  ├── Embedded CPython (PythonKernel)
  └── Notebook I/O (read/write .ipynb)
```

## Project Structure

```
zenji-notebook/
├── build.zig           # build script — also runs crawler to generate assets.zig
├── crawler.zig         # walks src/frontend/build/, generates src/assets.zig
├── src/
│   ├── main.zig
│   ├── c.h             # thin wrapper: #include <Python.h>
│   ├── types.zig       # CellResult, Variable, Module
│   ├── server/         # HTTP server, routing, middleware, static serving
│   ├── kernel/         # embedded kernel — kernel.zig dispatch + language backends
│   ├── notebook/       # .ipynb parsing and writing (in progress)
│   ├── api/            # REST handlers (in progress)
│   └── auth/           # token auth
└── src/frontend/       # SvelteKit app (bun + Tailwind v4)
```

## License

MIT
