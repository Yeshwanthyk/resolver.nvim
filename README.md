# resolver.nvim

Two-way diff for Git merge conflicts. Shows OURS vs THEIRS side-by-side.

Based on [vim-diffconflicts](https://github.com/whiteinge/diffconflicts) by Seth House.

## Installation

### lazy.nvim

```lua
{
  dir = "~/path/to/resolver",
}
```

## Usage

```bash
nvim -c ResolvePick
```

### Commands

| Command | Description |
|---------|-------------|
| `:Resolve` | Open two-way diff for current file |
| `:ResolveClose` | Close diff view |
| `:ResolveOurs` | Keep ours (left) |
| `:ResolveTheirs` | Take theirs (right) |
| `:ResolveBoth` | Combine both |
| `:ResolveRestore` | Restore original markers |
| `:ResolvePick` | File picker (requires snacks.nvim) |

### Keymaps (in diff view)

| Key | Action |
|-----|--------|
| `<leader>mo` | Keep ours |
| `<leader>mt` | Take theirs |
| `<leader>mb` | Both |
| `<leader>mr` | Restore |
| `<leader>mp` | Picker |

### Vim Builtins

| Key | Action |
|-----|--------|
| `]c` / `[c` | Next/prev diff hunk |
| `do` | Get hunk from other side |
| `dp` | Put hunk to other side |

## How It Works

### The Problem

When Git can't auto-merge, it writes conflict markers into your file:

```
<<<<<<< HEAD
our changes
||||||| base
original
=======
their changes
>>>>>>> feature
```

Editing these markers manually is error-prone. A 3-way diff is confusing.

### The Solution

This plugin shows a **two-way diff**:
- **Left (OURS)**: Your version, editable
- **Right (THEIRS)**: Their version, read-only reference

It works by:
1. Reading the file with conflict markers
2. Parsing markers with a state machine (NORMAL → OURS → BASE → THEIRS → NORMAL)
3. Extracting clean OURS and THEIRS versions (markers stripped)
4. Showing side-by-side with vim's `:diffthis`
5. You edit the left side, save with `:w`

### Git Integration

You can use this standalone or with `git mergetool`:

```bash
# Standalone (recommended)
nvim -c ResolvePick

# Or configure git mergetool
git config --global merge.tool resolver
git config --global mergetool.resolver.cmd 'nvim "$MERGED" -c Resolve'
git config --global mergetool.resolver.trustExitCode true
```

With standalone approach, you control the flow. With git mergetool, git opens each file one at a time.

## Credits

[vim-diffconflicts](https://github.com/whiteinge/diffconflicts) by Seth House — [Watch the explanation](https://www.youtube.com/watch?v=Pxgl3Wtf78Y)

## License

BSD 3-Clause
