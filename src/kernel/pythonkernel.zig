//! CPython kernel backend — executes code via the embedded interpreter.

const std = @import("std");
const python = @import("c");
const CellResult = @import("../types.zig").CellResult;
const Variable = @import("../types.zig").Variable;
const Module = @import("../types.zig").Module;

/// Injected before user code to redirect stdout/stderr to StringIO buffers.
const capture_setup =
    \\import io as _io, sys as _sys
    \\_old_stdout = _sys.stdout
    \\_old_stderr = _sys.stderr
    \\_sys.stdout = _io.StringIO()
    \\_sys.stderr = _io.StringIO()
;

/// Injected after user code to read captured output and collect matplotlib figures.
/// Uses bare except to handle cases where matplotlib isn't installed or sys.__file__ is missing.
const capture_teardown =
    \\_captured_stdout = _sys.stdout.getvalue()
    \\_captured_stderr = _sys.stderr.getvalue()
    \\_sys.stdout = _old_stdout
    \\_sys.stderr = _old_stderr
    \\_captured_figures = []
    \\try:
    \\    import matplotlib.pyplot as _plt
    \\    import base64 as _b64
    \\    for _fig_num in _plt.get_fignums():
    \\        _buf = _io.BytesIO()
    \\        _plt.figure(_fig_num).savefig(_buf, format='png')
    \\        _buf.seek(0)
    \\        _captured_figures.append(_b64.b64encode(_buf.read()).decode('utf-8'))
    \\        _plt.close(_fig_num)
    \\except:
    \\    pass
;

pub const PythonKernel = struct {
    globals: *python.PyObject,
    /// Points to the same dict as globals — top-level execution uses a single namespace.
    locals: *python.PyObject,
    allocator: std.mem.Allocator,

    /// Initialize the CPython interpreter and set up the execution namespace.
    /// Must be called before any other PythonKernel methods.
    pub fn init(allocator: std.mem.Allocator) PythonKernel {
        python.Py_Initialize();
        const globals = python.PyDict_New();
        _ = python.PyDict_SetItemString(globals, "__builtins__", python.PyEval_GetBuiltins());

        // Set matplotlib to non-interactive backend before anyone imports pyplot
        _ = python.PyRun_String("try:\n    import matplotlib\n    matplotlib.use('Agg')\nexcept:\n    pass", python.Py_file_input, globals, globals);
        python.PyErr_Clear(); // matplotlib init can leave stale errors on built-in modules

        // Release the GIL so httpz worker threads can acquire it via PyGILState_Ensure.
        _ = python.PyEval_SaveThread();

        return .{ .globals = globals, .locals = globals, .allocator = allocator };
    }

    /// Execute a cell of Python code. Captures stdout, stderr, and matplotlib figures.
    /// The code is sandwiched between capture_setup and capture_teardown before execution.
    pub fn execute(self: *PythonKernel, code: [*:0]const u8) !CellResult {
        // Acquire the GIL for the current thread. After PyEval_SaveThread() in init(),
        // the GIL is released — worker threads must re-acquire it before any Python C API call.
        const gil = python.PyGILState_Ensure();
        defer python.PyGILState_Release(gil);

        const full_code = try std.mem.concatWithSentinel(self.allocator, u8, &.{ capture_setup, "\n", std.mem.span(code), "\n", capture_teardown }, 0);
        defer self.allocator.free(full_code);

        const result = python.PyRun_String(full_code, python.Py_file_input, self.globals, self.locals);

        // All captured data lives in globals as Python objects — pull them out
        const stdout_obj = python.PyDict_GetItemString(self.globals, "_captured_stdout");
        const stderr_obj = python.PyDict_GetItemString(self.globals, "_captured_stderr");
        const captured_fig_obj = python.PyDict_GetItemString(self.globals, "_captured_figures");

        // Extract figure base64 strings — dupeZ so they're safe after further Python calls
        const figures: ?[]const [*:0]const u8 = if (captured_fig_obj != null and python.PyList_Size(captured_fig_obj) > 0) blk: {
            const count: usize = @intCast(python.PyList_Size(captured_fig_obj));
            const figs = try self.allocator.alloc([*:0]const u8, count);
            for (0..count) |i| {
                const item = python.PyList_GetItem(captured_fig_obj, @intCast(i));
                figs[i] = try self.allocator.dupeZ(u8, std.mem.span(python.PyUnicode_AsUTF8(item)));
            }
            break :blk figs;
        } else null;

        const stdout_str = if (stdout_obj != null) python.PyUnicode_AsUTF8(stdout_obj) else null;
        const stderr_str = if (stderr_obj != null) python.PyUnicode_AsUTF8(stderr_obj) else null;

        if (result == null) {
            python.PyErr_Print();
            if (figures) |figs| self.allocator.free(figs);
            return error.ExecutionFailed;
        }

        python.Py_DecRef(result); // new reference from PyRun_String — must decref
        return .{ .stdout = stdout_str, .stderr = stderr_str, .figures = figures };
    }

    /// Returns user-defined variables from the kernel namespace.
    /// Filters out underscore-prefixed names and module objects.
    /// Returned strings are allocator-owned copies (safe after Python GC).
    /// Caller must free the returned slice.
    pub fn getVariables(self: *PythonKernel) ![]const Variable {
        const gil = python.PyGILState_Ensure();
        defer python.PyGILState_Release(gil);

        var pos: python.Py_ssize_t = 0;
        var key: ?*python.PyObject = null;
        var value: ?*python.PyObject = null;

        // First pass: count qualifying entries
        var count: usize = 0;
        while (python.PyDict_Next(self.globals, &pos, &key, &value) != 0) {
            const name = python.PyUnicode_AsUTF8(key);
            const name_slice = std.mem.span(name);
            if (std.mem.startsWith(u8, name_slice, "_")) continue;

            const type_obj = python.PyObject_Type(value);
            const type_name_obj = python.PyObject_GetAttrString(type_obj, "__name__");
            defer python.Py_DecRef(type_obj);
            defer if (type_name_obj != null) python.Py_DecRef(type_name_obj);
            if (type_name_obj != null and std.mem.eql(u8, std.mem.span(python.PyUnicode_AsUTF8(type_name_obj)), "module")) continue;

            count += 1;
        }

        const vars = try self.allocator.alloc(Variable, count);

        // Second pass: copy data into allocator-owned strings
        pos = 0;
        var i: usize = 0;
        while (python.PyDict_Next(self.globals, &pos, &key, &value) != 0) {
            const name = python.PyUnicode_AsUTF8(key);
            const name_slice = std.mem.span(name);
            if (std.mem.startsWith(u8, name_slice, "_")) continue;

            const type_obj = python.PyObject_Type(value);
            const type_name_obj = python.PyObject_GetAttrString(type_obj, "__name__");
            defer python.Py_DecRef(type_obj);
            defer if (type_name_obj != null) python.Py_DecRef(type_name_obj);

            const type_name_str: [*:0]const u8 = if (type_name_obj != null) python.PyUnicode_AsUTF8(type_name_obj) else "unknown";
            if (std.mem.eql(u8, std.mem.span(type_name_str), "module")) continue;

            const repr = python.PyObject_Repr(value);
            defer python.Py_DecRef(repr);

            // dupeZ copies the string — necessary because PyObject_Repr's buffer is reused
            vars[i] = .{
                .name = try self.allocator.dupeZ(u8, std.mem.span(name)),
                .value = try self.allocator.dupeZ(u8, std.mem.span(python.PyUnicode_AsUTF8(repr))),
                .type_name = try self.allocator.dupeZ(u8, std.mem.span(type_name_str)),
            };

            i += 1;
        }

        return vars;
    }

    /// Returns imported modules from the kernel namespace.
    /// Filters out underscore-prefixed internal imports.
    /// Caller must free the returned slice.
    pub fn getModules(self: *PythonKernel) ![]const Module {
        const gil = python.PyGILState_Ensure();
        defer python.PyGILState_Release(gil);

        var pos: python.Py_ssize_t = 0;
        var key: ?*python.PyObject = null;
        var value: ?*python.PyObject = null;

        // First pass: count modules
        var count: usize = 0;
        while (python.PyDict_Next(self.globals, &pos, &key, &value) != 0) {
            const name = python.PyUnicode_AsUTF8(key);
            if (std.mem.startsWith(u8, std.mem.span(name), "_")) continue;

            const type_obj = python.PyObject_Type(value);
            const type_name_obj = python.PyObject_GetAttrString(type_obj, "__name__");
            defer python.Py_DecRef(type_obj);
            defer if (type_name_obj != null) python.Py_DecRef(type_name_obj);

            if (type_name_obj != null and std.mem.eql(u8, std.mem.span(python.PyUnicode_AsUTF8(type_name_obj)), "module")) {
                count += 1;
            }
        }

        const mods = try self.allocator.alloc(Module, count);

        // Second pass: fill the slice
        pos = 0;
        var i: usize = 0;
        while (python.PyDict_Next(self.globals, &pos, &key, &value) != 0) {
            const name = python.PyUnicode_AsUTF8(key);
            if (std.mem.startsWith(u8, std.mem.span(name), "_")) continue;

            const type_obj = python.PyObject_Type(value);
            const type_name_obj = python.PyObject_GetAttrString(type_obj, "__name__");
            defer python.Py_DecRef(type_obj);
            defer if (type_name_obj != null) python.Py_DecRef(type_name_obj);

            if (type_name_obj == null or !std.mem.eql(u8, std.mem.span(python.PyUnicode_AsUTF8(type_name_obj)), "module")) continue;

            // PyObject_GetAttrString raises AttributeError on built-in modules without __file__
            const file_obj = python.PyObject_GetAttrString(value, "__file__");
            python.PyErr_Clear(); // clear the pending error so it doesn't poison the next PyRun_String
            const path: [*:0]const u8 = if (file_obj != null) blk: {
                const p = try self.allocator.dupeZ(u8, std.mem.span(python.PyUnicode_AsUTF8(file_obj)));
                python.Py_DecRef(file_obj);
                break :blk p;
            } else "built-in";

            mods[i] = .{
                .name = try self.allocator.dupeZ(u8, std.mem.span(name)),
                .path = path,
            };

            i += 1;
        }

        return mods;
    }

    /// Shut down the CPython interpreter. No kernel methods may be called after this.
    pub fn deinit(_: *PythonKernel) void {
        _ = python.PyGILState_Ensure();
        python.Py_Finalize();
    }
};
