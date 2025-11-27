# AGENTS.md — ydiffconflicts.nvim

## Project Overview

A Neovim plugin that converts Git merge conflict markers into a two-way diff view for easier conflict resolution.

## Architecture

```
ydiffconflicts/
├── lua/ydiffconflicts/
│   └── init.lua          # Core plugin logic
├── plugin/
│   └── ydiffconflicts.lua # Plugin loader (lazy-load guard)
├── README.md
└── AGENTS.md
```

## Key Functions (`lua/ydiffconflicts/init.lua`)

| Function | Purpose |
|----------|---------|
| `has_conflicts()` | Scans buffer for `<<<<<<<` markers |
| `get_conflict_style()` | Detects `merge`, `diff3`, or `zdiff3` from git config |
| `diffconflicts()` | Main logic: splits into OURS (left) / THEIRS (right) diff |
| `find_buf(pattern)` | Finds buffer by name pattern (LOCAL, BASE, REMOTE) |
| `show_history()` | Opens LOCAL \| BASE \| REMOTE in a new tab |
| `cmd_diff()` | `:YDiffConflicts` command handler |
| `cmd_with_history()` | `:YDiffConflictsWithHistory` command handler |

## Commands Registered

- `:YDiffConflicts` — Two-way diff only
- `:YDiffConflictsShowHistory` — History tab only
- `:YDiffConflictsWithHistory` — Both (default for mergetool)

## Conflict Marker Parsing

The plugin uses Vim regex to strip markers:

```
<<<<<<< ours
our changes
||||||| base (only in diff3/zdiff3)
original
=======
their changes
>>>>>>> theirs
```

- **Left buffer (ours)**: Deletes from `=======` to `>>>>>>>` (or `|||||||` to `>>>>>>>` for diff3)
- **Right buffer (theirs)**: Deletes from `<<<<<<<` to `=======`

## Testing Changes

1. Create a merge conflict:
   ```bash
   git checkout -b test-branch
   echo "change" > file.txt && git commit -am "change"
   git checkout main
   echo "other" > file.txt && git commit -am "other"
   git merge test-branch  # creates conflict
   ```

2. Run mergetool:
   ```bash
   git mergetool
   ```

3. Or test directly in Neovim on a file with conflict markers:
   ```vim
   :YDiffConflicts
   ```

## Dependencies

- Neovim 0.7+ (uses `vim.api`, `vim.cmd`, `vim.bo`)
- Git (for `git config --get merge.conflictStyle`)

## Testing

Use the test script to create a repo with conflicts:

```bash
./test/make-conflicts.sh /tmp/test-conflicts
cd /tmp/test-conflicts
git mergetool
```

## Common Modifications

### Add a new command
```lua
vim.api.nvim_create_user_command('YDiffConflictsNew', function()
  -- your logic
end, {})
```

### Change default behavior
Edit `cmd_with_history()` in `init.lua`

### Add keybindings
The plugin doesn't set keybindings by default. Users add their own in their Neovim config.

## Origin

Lua port of [vim-diffconflicts](https://github.com/whiteinge/diffconflicts) by Seth House (BSD 3-Clause license).
