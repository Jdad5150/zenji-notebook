<script lang="ts">
	import { Plus } from '@lucide/svelte';
	import NotebookSidebar from '$lib/components/NotebookSidebar.svelte';
	import NotebookToolbar from '$lib/components/NotebookToolbar.svelte';
	import NotebookCell from '$lib/components/NotebookCell.svelte';
	import NotebookMenuBar from '$lib/components/NotebookMenuBar.svelte';
	import DataExplorer from '$lib/components/DataExplorer.svelte';
	import PlotLightbox from '$lib/components/PlotLightbox.svelte';
	import { mockPlots } from '$lib/mock-plots';

	let sidebarOpen = $state(true);
	let dataExplorerOpen = $state(true);
	let mode = $state<'edit' | 'view'>('edit');
	let notebookTitle = $state('Untitled Notebook');
	let kernel = $state('Python 3.11');
	let runtimeStatus = $state<'idle' | 'running' | 'error'>('idle');
	let activeCellId = $state<number | null>(null);
	let lightboxIndex = $state<number | null>(null);

	let cells = $state([
		{ id: 100, type: 'markdown' as const, content: `# Zenji Notebook Demo

This notebook demonstrates **all markdown features** to verify the *typography plugin* is rendering correctly.

## Text Formatting

Here's some **bold text**, *italic text*, ***bold and italic***, and ~~strikethrough~~. You can also use \`inline code\` within paragraphs.

## Links & Images

Check out [Zenji on GitHub](https://github.com/zenji) for more info. Here's an auto-linked URL: https://example.com

## Lists

### Unordered
- First item
- Second item with **bold**
  - Nested item
  - Another nested
- Third item

### Ordered
1. Step one
2. Step two
3. Step three
   1. Sub-step A
   2. Sub-step B

## Blockquotes

> "Any sufficiently advanced technology is indistinguishable from magic."
> — Arthur C. Clarke

> Nested quotes work too:
>
> > This is a nested blockquote.

## Code

Inline: use \`print("hello")\` to output text.

Block:
\`\`\`python
def fibonacci(n):
    a, b = 0, 1
    for _ in range(n):
        yield a
        a, b = b, a + b
\`\`\`

## Tables

| Feature | Status | Notes |
|---------|--------|-------|
| Syntax highlighting | ✅ | Shiki + Catppuccin |
| Markdown rendering | ✅ | marked + typography |
| Mode switching | ✅ | Edit / View |
| Cell management | ✅ | Add, delete, move |

## Horizontal Rule

---

## Math-like formatting

The area of a circle is *A = πr²*. When *r = 5*, we get *A ≈ 78.54*.

## Task Lists

- [x] Set up Shiki highlighting
- [x] Match CodeMirror theme
- [x] Implement view mode
- [ ] Connect to Zig backend
- [ ] Add real kernel execution`, output: '', rendered: true },

		{ id: 1, type: 'code' as const, content: `# ── Imports & Aliases ──
import os
import sys
from pathlib import Path
from typing import Optional, List, Dict, Tuple, Union
from dataclasses import dataclass, field
import numpy as np`, output: '', rendered: false },

		{ id: 2, type: 'code' as const, content: `# ── Constants, Numbers & Booleans ──
MAX_RETRIES = 3
PI = 3.14159
HEX_VAL = 0xFF
BIN_VAL = 0b1010
COMPLEX = 2 + 3j
SCIENTIFIC = 1.5e-10
is_active = True
is_deleted = False
nothing = None`, output: '', rendered: false },

		{ id: 3, type: 'code' as const, content: `# ── Strings: all variants ──
single = 'hello'
double = "world"
triple_single = '''multi
line string'''
triple_double = """another
multi-line"""
raw = r"no\\escape"
byte = b"bytes"
fstring = f"result: {2 + 2}"
fstring_nested = f"path: {Path.home()!r}"
fstring_format = f"pi is {PI:.4f}"`, output: '', rendered: false },

		{ id: 4, type: 'code' as const, content: `# ── Operators & Comparisons ──
x = 10 + 5 - 3 * 2 / 4 // 2 % 3 ** 2
y = x << 2 | x >> 1 & 0xFF ^ 0x0F
z = ~x
check = (x > 5) and (y < 100) or not (z == 0)
is_same = x is not None
in_list = x in [1, 2, 10]
ternary = "yes" if check else "no"
walrus = (n := 42)`, output: '', rendered: false },

		{ id: 5, type: 'code' as const, content: `# ── Builtin Functions ──
print("hello")
length = len([1, 2, 3])
items = list(range(10))
mapped = list(map(str, items))
filtered = list(filter(lambda x: x > "5", mapped))
total = sum(range(100))
biggest = max(1, 2, 3)
smallest = min(1, 2, 3)
rounded = round(3.14159, 2)
zipped = list(zip([1, 2], ["a", "b"]))
types = (int, float, str, bool, bytes, dict, set, tuple)
val = isinstance(42, int)
rep = repr({"key": "value"})
hashed = hash("immutable")
ident = id(object())
evaled = eval("2 + 2")
sorted_list = sorted([3, 1, 2], reverse=True)
enumerated = list(enumerate(["a", "b", "c"]))`, output: '', rendered: false, plotSrc: mockPlots.lineChart },

		{ id: 6, type: 'code' as const, content: `# ── Functions & Decorators ──
def simple_func(a, b=10):
    """A simple docstring."""
    return a + b

def typed_func(name: str, count: int = 1) -> List[str]:
    return [name] * count

def variadic(*args, **kwargs):
    pass

lambda_fn = lambda x, y: x + y

def decorator(func):
    def wrapper(*args, **kwargs):
        print(f"Calling {func.__name__}")
        return func(*args, **kwargs)
    return wrapper

@decorator
def greet(name: str) -> str:
    return f"Hello, {name}!"`, output: '', rendered: false },

		{ id: 7, type: 'code' as const, content: `# ── Classes & Inheritance ──
class Animal:
    species_count: int = 0

    def __init__(self, name: str, sound: str = "..."):
        self.name = name
        self.sound = sound
        Animal.species_count += 1

    def speak(self) -> str:
        return f"{self.name} says {self.sound}"

    @staticmethod
    def kingdom() -> str:
        return "Animalia"

    @classmethod
    def count(cls) -> int:
        return cls.species_count

    @property
    def info(self) -> str:
        return f"{self.name} ({self.sound})"

    def __repr__(self) -> str:
        return f"Animal({self.name!r})"

class Dog(Animal):
    def __init__(self, name: str):
        super().__init__(name, "Woof")

    def speak(self) -> str:
        return f"{self.name} barks!"`, output: '', rendered: false },

		{ id: 8, type: 'code' as const, content: `# ── Dataclass ──
@dataclass
class Point:
    x: float
    y: float
    label: str = "origin"
    tags: List[str] = field(default_factory=list)

    def distance(self, other: "Point") -> float:
        return ((self.x - other.x) ** 2 + (self.y - other.y) ** 2) ** 0.5`, output: '', rendered: false },

		{ id: 9, type: 'code' as const, content: `# ── Control Flow ──
for i in range(5):
    if i == 0:
        continue
    elif i == 4:
        break
    else:
        print(i)

while False:
    pass

# Comprehensions
squares = [x ** 2 for x in range(10)]
evens = [x for x in range(20) if x % 2 == 0]
matrix = [[i * j for j in range(3)] for i in range(3)]
unique = {x % 5 for x in range(20)}
lookup = {k: v for k, v in enumerate("abcde")}
gen = (x ** 2 for x in range(10))`, output: '', rendered: false, plotSrc: mockPlots.barChart },

		{ id: 10, type: 'code' as const, content: `# ── Exception Handling ──
try:
    result = 1 / 0
except ZeroDivisionError as e:
    print(f"Caught: {e}")
except (TypeError, ValueError):
    print("Type or value error")
except Exception:
    raise
else:
    print("No error")
finally:
    print("Cleanup")

# Custom exception
class ZenjiError(Exception):
    def __init__(self, msg: str, code: int = 500):
        super().__init__(msg)
        self.code = code

# Context manager
with open("/dev/null", "w") as f:
    f.write("test")`, output: '', rendered: false },

		{ id: 11, type: 'code' as const, content: `# ── Async / Await ──
import asyncio

async def fetch_data(url: str) -> dict:
    await asyncio.sleep(0.1)
    return {"url": url, "status": 200}

async def main():
    tasks = [fetch_data(f"https://api.example.com/{i}") for i in range(5)]
    results = await asyncio.gather(*tasks)
    async for item in async_gen():
        print(item)

async def async_gen():
    for i in range(3):
        yield i
        await asyncio.sleep(0)`, output: '', rendered: false },

		{ id: 12, type: 'code' as const, content: `# ── Unpacking, Slicing & Misc ──
a, b, *rest = [1, 2, 3, 4, 5]
(x, y), z = (1, 2), 3
data = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
sliced = data[2:8:2]
reversed_data = data[::-1]

# Dict merge (3.9+)
d1 = {"a": 1}
d2 = {"b": 2}
merged = d1 | d2

# Match statement (3.10+)
command = "quit"
match command:
    case "quit" | "exit":
        print("Goodbye")
    case str(s) if s.startswith("go"):
        print(f"Going to {s[3:]}")
    case _:
        print("Unknown")

# Assert & Delete
assert len(data) == 10, "Expected 10 items"
temp = "delete me"
del temp

# Global / Nonlocal
def outer():
    count = 0
    def inner():
        nonlocal count
        count += 1
    inner()
    return count`, output: '', rendered: false, plotSrc: mockPlots.scatterPlot },
	]);

	let nextId = $state(13);

	// Extract headings from markdown cells for TOC
	const tocEntries = $derived(
		cells
			.filter((c) => c.type === 'markdown')
			.flatMap((c) =>
				c.content.split('\n')
					.filter((line) => line.startsWith('#'))
					.map((line) => {
						const level = line.match(/^#+/)?.[0].length ?? 1;
						const text = line.replace(/^#+\s*/, '');
						return { text, level, cellId: c.id };
					})
			)
	);

	let activeCellType = $derived(
		cells.find((c) => c.id === activeCellId)?.type ?? 'code'
	);

	// Collect all plots for the gallery and lightbox
	const allPlots = $derived(
		cells
			.filter((c) => c.plotSrc)
			.map((c) => ({ cellId: c.id, src: c.plotSrc!, title: `Cell ${c.id} output` }))
	);

	function openPlotLightbox(cellId: number) {
		const idx = allPlots.findIndex((p) => p.cellId === cellId);
		if (idx >= 0) lightboxIndex = idx;
	}

	function runCell(id: number) {
		const cell = cells.find((c) => c.id === id);
		if (cell?.type === 'markdown') {
			cell.rendered = true;
		}
		activeCellId = null;
		runtimeStatus = 'running';
		setTimeout(() => {
			runtimeStatus = 'idle';
		}, 800);
	}

	function addCell(type: 'code' | 'markdown' = 'code', atIndex?: number) {
		const id = nextId++;
		const newCell = { id, type, content: '', output: '', rendered: false };
		if (atIndex !== undefined) {
			cells = [...cells.slice(0, atIndex), newCell, ...cells.slice(atIndex)];
		} else {
			cells = [...cells, newCell];
		}
		activeCellId = id;
	}

	function setActiveCellType() {
		const cell = cells.find((c) => c.id === activeCellId);
		if (cell) cell.type = cell.type === 'code' ? 'markdown' : 'code';
	}

	function deleteCell(id: number) {
		cells = cells.filter((c) => c.id !== id);
		if (activeCellId === id) activeCellId = null;
	}

	function moveCell(index: number, direction: -1 | 1) {
		const target = index + direction;
		if (target < 0 || target >= cells.length) return;
		const updated = [...cells];
		[updated[index], updated[target]] = [updated[target], updated[index]];
		cells = updated;
	}

	function setMode(newMode: 'edit' | 'view') {
		mode = newMode;
		if (newMode === 'view') activeCellId = null;
	}
</script>

<div class="flex h-screen overflow-hidden bg-background">
	{#if mode === 'edit'}
		<NotebookSidebar open={sidebarOpen} ontoggle={() => (sidebarOpen = !sidebarOpen)} />
	{/if}

	<!-- Main content column -->
	<div class="flex flex-1 flex-col overflow-hidden">
		<!-- Title bar -->
		<div class="border-b border-border">
			<div class="flex items-center gap-3 px-4 py-1.5">
				{#if mode === 'edit'}
					<input
						type="text"
						bind:value={notebookTitle}
						aria-label="Notebook title"
						class="min-w-0 flex-1 truncate bg-transparent text-[16px] font-medium text-foreground outline-none placeholder:text-muted-foreground hover:bg-white/[0.03] focus:bg-white/[0.03] rounded-md px-2 py-1"
					/>
				{:else}
					<span class="min-w-0 flex-1 truncate text-[16px] font-medium text-foreground px-2 py-1">{notebookTitle}</span>
				{/if}
			</div>
			{#if mode === 'edit'}
				<NotebookMenuBar />
			{/if}
		</div>

		<!-- Body -->
		<div class="flex flex-1 overflow-hidden">
			<div class="flex flex-1 flex-col overflow-hidden">
				<NotebookToolbar
					{mode}
					{activeCellType}
					{kernel}
					{runtimeStatus}
					{dataExplorerOpen}
					onaddcell={() => addCell()}
					onsetcelltype={setActiveCellType}
					onsetmode={setMode}
					ontoggleexplorer={() => (dataExplorerOpen = !dataExplorerOpen)}
				/>

				<!-- Cell area -->
				<div class="flex-1 overflow-y-auto bg-background">
					<div class="{mode === 'view' ? 'mx-auto max-w-4xl px-8' : 'px-4'} py-4">
						{#each cells as cell, index (cell.id)}
							<NotebookCell
								{cell}
								{index}
								isActive={activeCellId === cell.id}
								isLast={index === cells.length - 1}
								{mode}
								onrun={() => runCell(cell.id)}
								onactivate={() => (activeCellId = cell.id)}
								onchange={(val) => (cell.content = val)}
								ondelete={() => deleteCell(cell.id)}
								onmove={(dir) => moveCell(index, dir)}
								onaddcell={(type, at) => addCell(type, at)}
								onunrender={() => (cell.rendered = false)}
								onopenplot={(id) => openPlotLightbox(id)}
							/>
						{/each}

						{#if mode === 'edit'}
							<div class="flex items-center justify-center gap-2 py-6 ml-10 mr-10">
								<button
									class="flex items-center gap-1.5 rounded-lg border border-dashed border-white/[0.06] px-4 py-2 text-[13px] text-muted-foreground/50 transition-colors hover:border-white/[0.12] hover:text-foreground"
									onclick={() => addCell('code')}
								>
									<Plus class="h-3.5 w-3.5" />
									Code
								</button>
								<button
									class="flex items-center gap-1.5 rounded-lg border border-dashed border-white/[0.06] px-4 py-2 text-[13px] text-muted-foreground/50 transition-colors hover:border-white/[0.12] hover:text-foreground"
									onclick={() => addCell('markdown')}
								>
									<Plus class="h-3.5 w-3.5" />
									Markdown
								</button>
							</div>
						{/if}
					</div>
				</div>
			</div>

			{#if mode === 'edit'}
				<div class="flex shrink-0 flex-col border-l border-border overflow-hidden {dataExplorerOpen ? 'w-72' : 'w-0 border-l-0'} transition-[width] duration-200">
					{#if dataExplorerOpen}
						<DataExplorer {tocEntries} plots={allPlots} onopenplot={(idx) => lightboxIndex = idx} />
					{/if}
				</div>
			{/if}
		</div>
	</div>
</div>

{#if lightboxIndex !== null}
	<PlotLightbox
		plots={allPlots}
		currentIndex={lightboxIndex}
		onclose={() => lightboxIndex = null}
		onnavigate={(idx) => lightboxIndex = idx}
	/>
{/if}
