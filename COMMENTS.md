# Zig Comment Standard

This document defines the comment conventions for all Zig source files in this repository.
All contributors and AI tools must follow this standard exactly. Do not invent formats not defined here.

---

## Guiding Principle

> **Comments explain intent and contract. Code explains mechanism.**

If a comment describes *what* the code does, rewrite the code to be clearer instead.
Comments are for **why**, **invariants**, **units**, and **non-obvious behavior**.

---

## Comment Types

### `//!` — File/Module Doc (top of file only)

Every `.zig` file begins with a `//!` block. It answers:
- What is this module responsible for?
- What is its role in the larger system?
- Any critical constraints or assumptions a reader needs before reading anything else.

**Format:**
```zig
//! Brief one-line summary of this module.
//!
//! Extended description if needed. Keep it to what a new dev needs
//! to orient themselves before reading any declarations.
//! Mention key dependencies or invariants if non-obvious.
```

**Example:**
```zig
//! ZMQ transport layer for Zenji kernel communication.
//!
//! Manages the request/reply socket lifecycle for a single kernel session.
//! Assumes the kernel process is already spawned before Connect() is called.
//! All socket operations are blocking; call from a dedicated thread.
```

**Rules:**
- Required on every file, no exceptions.
- First line is always a single sentence summary.
- Do not list every function — that's what `///` is for.
- Maximum ~6 lines. If you need more, the module is probably doing too much.

---

### `///` — Declaration Doc (public symbols)

Every `pub` function, struct, union, enum, and constant gets a `///` doc comment.
Private declarations get one only if the logic is non-obvious.

**Format:**
```zig
/// Brief one-line summary. First sentence is the preview in doc listings.
///
/// Extended explanation if needed. Describe semantics, not mechanics.
/// Cover: preconditions, postconditions, error conditions, side effects.
/// Do NOT re-describe parameter types — the signature already does that.
pub fn doThing(input: Input) Error!Output
```

**Example — function:**
```zig
/// Writes a calibration frame into the output buffer.
///
/// Caller must ensure `output_buf` has capacity for at least one full frame.
/// Returns the number of bytes written. Returns 0 if the frame queue is empty.
/// Does not flush — call `flushFrames()` after all frames are written.
pub fn writeCalibrationFrame(output_buf: []u8, frame_count: usize) usize
```

**Example — struct:**
```zig
/// Represents a single calibration label ready for printing.
///
/// All string fields are slices into the parent `LabelBatch` arena.
/// Do not free individual fields — free the arena when the batch is done.
pub const CalibrationLabel = struct {
    serial: []const u8,
    part_number: []const u8,
    calibration_date: []const u8, // ISO 8601 format: YYYY-MM-DD
    expiry_date: []const u8,      // ISO 8601 format: YYYY-MM-DD
};
```

**Example — error set:**
```zig
/// Errors that can occur during MES data fetch.
pub const MesError = error{
    /// The asset ID was not found in the current campaign.
    AssetNotFound,
    /// Response payload exceeded the expected schema version.
    SchemaMismatch,
    /// Network timeout waiting for MES response.
    Timeout,
};
```

**Rules:**
- First line is always a single sentence summary — this is what doc tools and IDE hover show.
- Blank `///` line between the summary and extended body.
- Do not write `@param` or `@return` tags — Zig autodoc reads the signature directly.
- Describe units for numeric parameters that are not obvious from the type.
- Describe ownership/lifetime for slice and pointer parameters.
- Describe what errors actually mean, not just that they exist.

---

### `//` — Inline Implementation Comment

Used inside function bodies. Explains **why** a decision was made, not what the code does.

**When to use:**
- Non-obvious algorithm choice or workaround
- Magic numbers or constants that can't be named
- Preconditions being asserted or relied upon
- Anything future-you will question at 2am

**When NOT to use:**
- Describing what the next line obviously does
- Restating variable names in prose
- Commented-out code (delete it — use git)

**Format:** Single line, immediately above the relevant code. No trailing inline comments on complex lines.

```zig
// Prefer this:
// ZLS requires the socket to be closed before re-binding on the same port.
socket.close();
try socket.bind(addr);

// Not this:
socket.close(); // close socket
try socket.bind(addr); // bind to address
```

**Multi-line inline comments** use stacked `//` with a blank `//` between paragraphs:
```zig
// The frame header uses a non-standard byte order inherited from the v1 protocol.
// Swapping to little-endian here avoids a conversion on every read downstream.
//
// If the protocol ever standardizes, remove this and update the frame parser.
const header = std.mem.nativeToBig(u32, raw_header);
```

---

### Tagged Annotations

Use these tags consistently. Always uppercase, always followed by a colon and a space.

| Tag | Meaning |
|-----|---------|
| `// TODO: ` | Known missing feature or incomplete implementation |
| `// FIXME: ` | Known bug or incorrect behavior that needs correction |
| `// NOTE: ` | Important context that doesn't fit elsewhere |
| `// HACK: ` | Intentional workaround — document why and what the clean solution is |
| `// SAFETY: ` | Explains why an unsafe or unchecked operation is correct |

**Format:**
```zig
// TODO: Replace Smartsheet fetch with MES endpoint once data migration completes.
// FIXME: Frame count overflows on batches larger than 65535 — needs u32 promotion.
// NOTE: ZLS does not yet resolve comptime-generated type names in hover tooltips.
// HACK: Brother SDK requires a 50ms delay between print jobs or it silently drops.
//       Clean fix is to poll the printer status queue instead.
// SAFETY: input.len is validated by the caller before this point; indexing is safe.
```

**Rules:**
- One tag per comment.
- `HACK` always includes what the proper solution is.
- `SAFETY` is required on any `@ptrCast`, unchecked index, or assumption that bypasses a runtime check.

---

### `comptime` Blocks

`comptime` logic is real logic — comment it like a function, not like a type annotation.

```zig
// Selects the correct integer type to hold `count` values without overflow.
// Used at comptime to size the index array statically with no runtime cost.
const IndexType = comptime blk: {
    if (count <= std.math.maxInt(u8)) break :blk u8;
    if (count <= std.math.maxInt(u16)) break :blk u16;
    break :blk u32;
};
```

---

## Units and Value Semantics

When a numeric value has a unit or a specific valid range that isn't encoded in the type, document it inline on the field or parameter declaration.

```zig
pub const SensorReading = struct {
    timestamp_ns: u64,    // nanoseconds since UNIX epoch
    temperature_mc: i32,  // millidegrees Celsius
    pressure_pa: u32,     // Pascals; valid range 80_000..110_000
    sample_count: u16,    // must be > 0; caller-validated
};
```

If a function parameter has a constrained valid range not enforced by the type, document it in the `///` block:
```zig
/// Converts raw ADC counts to calibrated voltage.
///
/// `adc_counts` must be in range 0..4095 (12-bit ADC).
/// Behavior is undefined for values outside this range — no runtime check is performed.
pub fn adcToVoltage(adc_counts: u16, ref_voltage_mv: u32) u32
```

---

## What NOT to Do

```zig
// BAD: Restates the code
i += 1; // increment i

// BAD: Obvious from the name
pub fn initAllocator() void // Initialize the allocator

// BAD: Commented-out code
// const old_result = legacyCompute(x);
const result = compute(x);

// BAD: Wall of text with no structure
// This function does the thing where it takes the input and processes it through
// the pipeline and returns the result after checking everything is okay and the
// buffer has enough space and the connection is alive...
pub fn process(input: Input) !Output

// BAD: No file doc
const std = @import("std"); // first line of file, no //! above it
```

---

## Summary Reference

| Comment | Where | Required |
|---------|-------|----------|
| `//!` | Top of every `.zig` file | Always |
| `///` | Every `pub` declaration | Always |
| `///` | Private declarations | If non-obvious |
| `//` | Inside function bodies | When explaining *why* |
| `// TAG:` | Anywhere | When applicable |

---

## Claude Code Directive

When reviewing, writing, or documenting any Zig source file in this repository:

1. Read this entire document before touching any `.zig` file.
2. Every file must have a `//!` header. If one is missing, add it.
3. Every `pub` declaration must have a `///` doc comment. If one is missing, add it.
4. Do not invent comment formats not defined here.
5. Do not write inline comments that describe what the code does — only why.
6. Apply unit annotations to all numeric fields where the unit is not encoded in the name or type.
7. When in doubt, less is more. A missing comment is better than a misleading one.
