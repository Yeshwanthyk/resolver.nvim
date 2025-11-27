# AGENTS.md — resolver.nvim

## Overview

Two-way diff for Git merge conflicts. Shows OURS (left) vs THEIRS (right).

## Files

```
lua/resolver/init.lua    # All logic (~190 lines)
plugin/resolver.lua      # Loader
```

## Commands

- `:Resolve` — Open two-way diff
- `:ResolveClose` — Close diff  
- `:ResolveOurs` — Keep ours
- `:ResolveTheirs` — Take theirs
- `:ResolveBoth` — Combine both
- `:ResolveRestore` — Restore original
- `:ResolvePick` — File picker

## Keymaps

`<leader>mo/mt/mb/mr/mp`

## How It Works

1. Read file with conflict markers from disk
2. State machine parses: NORMAL → OURS → BASE → THEIRS → NORMAL  
3. Extract clean OURS/THEIRS (strip markers)
4. Show side-by-side with `:diffthis`
5. User edits left, saves with `:w`

## Testing

```bash
nvim -c ResolvePick
```
