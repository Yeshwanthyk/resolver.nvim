# AGENTS.md — ydiffconflicts.nvim

## Overview

Two-way diff viewer for Git merge conflicts. Opens all conflicted files in quickfix, then shows OURS vs THEIRS side-by-side.

## Files

```
lua/ydiffconflicts/init.lua   # All logic (~200 lines)
plugin/ydiffconflicts.lua     # Loader
```

## Key Functions

| Function | Purpose |
|----------|---------|
| `get_conflicted_files()` | Runs `git diff --name-only --diff-filter=U` |
| `populate_quickfix()` | Builds quickfix list with conflict counts |
| `open_diff_view()` | Creates OURS (left) / THEIRS (right) split |
| `close_diff_view()` | Closes THEIRS buffer, turns off diff mode |
| `choose_all(side)` | Takes ours or theirs entirely |
| `mark_resolved()` | Saves file and runs `git add` |
| `start()` | Main entry: quickfix + auto-open first file |

## Commands

- `:YDiffList` — Start resolving (quickfix + first file)
- `:YDiffOpen` — Open diff view for current file
- `:YDiffClose` — Close diff view
- `:YDiffOurs` — Keep ours
- `:YDiffTheirs` — Take theirs
- `:YDiffResolved` — Mark file resolved

## How Two-Way Diff Works

1. Copy buffer lines to new THEIRS buffer
2. Strip conflict markers differently for each side:
   - OURS: Remove `=======` through `>>>>>>>` (and `|||||||` in diff3)
   - THEIRS: Remove `<<<<<<<` through `=======`
3. Run `:diffthis` on both
4. User edits OURS, uses `:diffget` to pull from THEIRS
5. Save writes back to original file

## Testing

```bash
./test/make-conflicts.sh /tmp/test
cd /tmp/test
nvim -c YDiffList
```

## Origin

Lua port of [vim-diffconflicts](https://github.com/whiteinge/diffconflicts) by Seth House.
