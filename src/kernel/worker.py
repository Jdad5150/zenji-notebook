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
    import matplotlib  # type: ignore
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
        import matplotlib.pyplot as plt  # type: ignore
        for n in plt.get_fignums():
            buf = io.BytesIO()
            plt.figure(n).savefig(buf, format='png')
            buf.seek(0)
            figs.append(base64.b64encode(buf.read()).decode())
            plt.close(n)
    except Exception:
        pass

    return {'stdout': out, 'stderr': err, 'figures': figs}


def _classify(value) -> tuple[str, str | None]:
    """Return (kind, shape) for a variable. Never raises."""
    try:
        # bool must come before int — bool is a subclass of int
        if isinstance(value, bool):
            return 'scalar', None
        if isinstance(value, (int, float, complex)):
            return 'scalar', None
        if isinstance(value, str):
            return 'string', None
        if isinstance(value, dict):
            return 'mapping', str(len(value))
        if isinstance(value, (list, tuple, set, frozenset)):
            return 'sequence', str(len(value))
        try:
            import numpy as np
            if isinstance(value, np.generic):
                return 'scalar', None
            if isinstance(value, np.ndarray):
                if value.ndim == 1:
                    return 'sequence', str(value.shape[0])
                if value.ndim == 2:
                    return 'matrix', f'{value.shape[0]} × {value.shape[1]}'
                return 'tensor', str(list(value.shape))
        except Exception:
            pass
        try:
            import pandas as pd
            if isinstance(value, pd.DataFrame):
                r, c = value.shape
                return 'dataframe', f'{r} × {c}'
            if isinstance(value, pd.Series):
                return 'sequence', str(len(value))
        except Exception:
            pass
        if callable(value):
            return 'function', None
    except Exception:
        pass
    return 'other', None


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
            if len(r) > 300:
                r = r[:300] + '…'
        except Exception:
            r = '<error>'
        kind, shape = _classify(value)
        result.append({'name': name, 'value': r, 'type': t, 'kind': kind, 'shape': shape})
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
