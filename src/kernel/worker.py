"""
Zenji notebook Python kernel worker.

Reads JSON commands from stdin, executes them, writes JSON responses to stdout.
Stays alive the whole session so variables persist between cell executions.

Protocol (one JSON object per line, newline-delimited):
  Input:  {"cmd": "execute",   "code": "..."}
          {"cmd": "variables"}
          {"cmd": "modules"}
          {"cmd": "quit"}
  Output: {"stdout": "...", "stderr": "...", "figures": ["<base64-png>", ...]}
          {"variables": [{"name": "...", "value": "...", "type": "..."}]}
          {"modules":   [{"name": "...", "path": "..."}]}
"""

import sys
import io
import json
import base64
import textwrap
import traceback
import warnings
import types as _types

# Global execution namespace — variables persist across cells.
_globals: dict = {}

# Point matplotlib at a non-interactive backend before anyone imports pyplot.
# Suppress the "FigureCanvasAgg is non-interactive" warning from plt.show().
try:
    import matplotlib
    matplotlib.use('Agg')
    warnings.filterwarnings('ignore', message='FigureCanvasAgg is non-interactive')
except Exception:
    pass


def _execute(code: str) -> dict:
    old_out, old_err = sys.stdout, sys.stderr
    sys.stdout = io.StringIO()
    sys.stderr = io.StringIO()
    error: str | None = None
    try:
        exec(compile(textwrap.dedent(code), '<cell>', 'exec'), _globals)
    except Exception:
        error = traceback.format_exc()

    out = sys.stdout.getvalue()
    err = sys.stderr.getvalue()
    sys.stdout, sys.stderr = old_out, old_err

    if error:
        err = (err + '\n' + error).strip('\n')

    figs: list[str] = []
    try:
        import matplotlib.pyplot as plt
        for n in plt.get_fignums():
            buf = io.BytesIO()
            plt.figure(n).savefig(buf, format='png')
            buf.seek(0)
            figs.append(base64.b64encode(buf.read()).decode())
            plt.close(n)
    except Exception:
        pass

    return {'stdout': out, 'stderr': err, 'figures': figs}


def _variables() -> dict:
    result = []
    for name, value in _globals.items():
        if name.startswith('_'):
            continue
        t = type(value).__name__
        if t == 'module':
            continue
        try:
            r = repr(value)
        except Exception:
            r = '<error>'
        result.append({'name': name, 'value': r, 'type': t})
    return {'variables': result}


def _modules() -> dict:
    result = []
    for name, value in _globals.items():
        if name.startswith('_'):
            continue
        if not isinstance(value, _types.ModuleType):
            continue
        path = getattr(value, '__file__', None) or 'built-in'
        result.append({'name': name, 'path': path})
    return {'modules': result}


# Main command loop — one JSON command in, one JSON response out.
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        msg = json.loads(line)
    except json.JSONDecodeError:
        continue

    cmd = msg.get('cmd', '')
    if cmd == 'execute':
        resp = _execute(msg.get('code', ''))
    elif cmd == 'variables':
        resp = _variables()
    elif cmd == 'modules':
        resp = _modules()
    elif cmd == 'quit':
        break
    else:
        resp = {'error': f'unknown cmd: {cmd}'}

    sys.stdout.write(json.dumps(resp) + '\n')
    sys.stdout.flush()
