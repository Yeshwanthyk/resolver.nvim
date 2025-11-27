# AGENTS.md — ydiffconflicts.nvim

## Overview

Two-way diff viewer for Git merge conflicts. Shows OURS (left, editable) vs THEIRS (right, read-only).

## Files

```
lua/ydiffconflicts/init.lua   # All logic (~170 lines)
plugin/ydiffconflicts.lua     # Loader
```

## Commands

- `:YDiff` — Open two-way diff
- `:YDiffClose` — Close diff view  
- `:YDiffOurs` — Keep ours
- `:YDiffTheirs` — Take theirs
- `:YDiffBoth` — Combine both
- `:YDiffRestore` — Restore original
- `:YDiffPick` — File picker (snacks.nvim)

## Keymaps (in diff)

`<leader>mo/mt/mb/mr/mp`

## How It Works

1. Read file with conflict markers from disk
2. Parse with state machine: NORMAL → OURS → BASE → THEIRS → NORMAL
3. Extract OURS and THEIRS versions (strip markers)
4. Show side-by-side with `:diffthis`
5. User edits left side, saves with `:w`

## Testing

```bash
cd /path/to/repo/with/conflicts
nvim -c YDiffPick
```

## Origin

Lua port of [vim-diffconflicts](https://github.com/whiteinge/diffconflicts) by Seth House.
