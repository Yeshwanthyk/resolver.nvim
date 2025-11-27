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

When you hit a merge conflict:

```bash
git mergetool
```

This opens Neovim with:
- **Tab 1**: Two-way diff — OURS (left, editable) vs THEIRS (right, read-only)
- **Tab 2**: History view — LOCAL | BASE | REMOTE (all read-only, for reference)

### Workflow

1. Conflicts open in a two-way diff view
2. Edit the **left side** to resolve conflicts
3. Use `:diffget` / `:diffput` or manual editing
4. Save with `:w` and quit with `:q`
5. Use `:cq` to abort (tells Git the merge failed)

### Commands

| Command | Description |
|---------|-------------|
| `:YDiffConflicts` | Convert conflict markers to two-way diff |
| `:YDiffConflictsShowHistory` | Open LOCAL \| BASE \| REMOTE in a new tab |
| `:YDiffConflictsWithHistory` | Both: two-way diff + history tab |

### Keybindings (suggestions)

Add to your Neovim config:

```lua
-- Get change from other side
vim.keymap.set('n', '<leader>dg', ':diffget<CR>')
-- Put change to other side  
vim.keymap.set('n', '<leader>dp', ':diffput<CR>')
-- Next/prev conflict
vim.keymap.set('n', ']c', ']c')
vim.keymap.set('n', '[c', '[c')
```

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
