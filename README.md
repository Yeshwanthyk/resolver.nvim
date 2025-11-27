# ydiffconflicts.nvim

A Neovim plugin for resolving Git merge conflicts using a two-way diff view. Pure Lua port of Seth House's [vim-diffconflicts](https://github.com/whiteinge/diffconflicts).

## Why?

The standard 3-way or 4-way diff mergetool is confusing. This plugin converts conflict markers into a simple **two-way diff** showing "ours" (left) vs "theirs" (right). You resolve conflicts by editing the left side.

## Installation

### lazy.nvim

```lua
{
  "yesh/ydiffconflicts",
  config = function()
    require("ydiffconflicts")
  end,
}
```

### packer.nvim

```lua
use { "yesh/ydiffconflicts" }
```

### Manual

Clone to your Neovim packages directory:

```bash
git clone https://github.com/yesh/ydiffconflicts ~/.local/share/nvim/site/pack/plugins/start/ydiffconflicts
```

## Git Mergetool Setup

Add to your `~/.gitconfig`:

```gitconfig
[merge]
    tool = ydiffconflicts
    conflictStyle = zdiff3   # recommended, also works with diff3 or default

[mergetool "ydiffconflicts"]
    cmd = nvim -c 'YDiffConflictsWithHistory' "$MERGED" "$LOCAL" "$BASE" "$REMOTE"
    trustExitCode = true
    keepBackup = false
```

Or run:

```bash
git config --global merge.tool ydiffconflicts
git config --global merge.conflictStyle zdiff3
git config --global mergetool.ydiffconflicts.cmd 'nvim -c "YDiffConflictsWithHistory" "$MERGED" "$LOCAL" "$BASE" "$REMOTE"'
git config --global mergetool.ydiffconflicts.trustExitCode true
git config --global mergetool.ydiffconflicts.keepBackup false
```

## Usage

After a failed merge:

```bash
nvim -c YDiffList
```

Or add a git alias:

```bash
git config --global alias.resolve '!nvim -c YDiffList'
git resolve
```

### Workflow

1. `:YDiffList` opens quickfix with all conflicted files
2. First file auto-opens in two-way diff: **OURS (left, editable)** vs **THEIRS (right, read-only)**
3. Use `:diffget` to pull changes from THEIRS, or edit OURS directly
4. Use `]c` / `[c` to jump between diff hunks
5. `:w` to save, then `:YDiffResolved` to mark done (runs `git add`)
6. `:cnext` to move to next file, `:YDiffOpen` to start diff view

### Commands

| Command | Description |
|---------|-------------|
| `:YDiffList` | Open quickfix with all conflicts, start resolving |
| `:YDiffOpen` | Open two-way diff for current file |
| `:YDiffClose` | Close the diff view |
| `:YDiffOurs` | Keep ours (left side), close diff |
| `:YDiffTheirs` | Take theirs (right side), close diff |
| `:YDiffResolved` | Save and mark resolved (`git add`) |

### Keymaps (in diff view)

| Key | Action |
|-----|--------|
| `]c` / `[c` | Next/prev diff hunk (vim builtin) |
| `:diffget` | Pull hunk from THEIRS |
| `<leader>co` | Keep all ours |
| `<leader>ct` | Take all theirs |
| `<leader>cd` | Mark resolved |

## How It Works

1. Detects conflict style (`merge`, `diff3`, or `zdiff3`)
2. Parses conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`, `|||||||`)
3. Creates two buffers:
   - Left: "ours" version (conflict markers stripped)
   - Right: "theirs" version (read-only)
4. Runs `:diffthis` on both for visual diff
5. Optionally shows LOCAL/BASE/REMOTE in a second tab

## Conflict Styles

Works with all Git conflict styles:

- **merge** (default): Shows ours and theirs
- **diff3**: Also shows base version in markers
- **zdiff3** (recommended): Like diff3 but cleaner

Set your preferred style:

```bash
git config --global merge.conflictStyle zdiff3
```

## Credits

This plugin is a pure Lua port of [vim-diffconflicts](https://github.com/whiteinge/diffconflicts), originally created by **Seth House**. All credit for the concept, algorithm, and original implementation belongs to him.

Watch Seth's excellent explanation of why two-way diffs are better:
[![Video Demo](https://img.youtube.com/vi/Pxgl3Wtf78Y/0.jpg)](https://www.youtube.com/watch?v=Pxgl3Wtf78Y)

## License

BSD 3-Clause — see [LICENSE](LICENSE)

```
Copyright (c) 2015, Seth House (original vim-diffconflicts)
Copyright (c) 2024, yesh (Lua port)
```
