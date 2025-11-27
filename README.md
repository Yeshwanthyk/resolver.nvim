# ydiffconflicts.nvim

Two-way diff for Git merge conflicts. Pure Lua port of Seth House's [vim-diffconflicts](https://github.com/whiteinge/diffconflicts).

## Installation

### lazy.nvim

```lua
{
  dir = "~/path/to/ydiffconflicts",
}
```

## Usage

```bash
# Open picker to select conflicted file
nvim -c YDiffPick

# Or open a specific file
nvim README.md -c YDiff
```

### Workflow

1. `:YDiffPick` - opens picker with all conflicted files
2. Select file → opens two-way diff: **OURS (left)** | **THEIRS (right)**
3. Edit left side, use `do` / `:diffget` to pull from right
4. Or use keymaps to take whole side
5. `:w` to save
6. `<leader>mp` to pick next file

### Commands

| Command | Description |
|---------|-------------|
| `:YDiff` | Open two-way diff for current file |
| `:YDiffClose` | Close diff view |
| `:YDiffOurs` | Keep ours (left) |
| `:YDiffTheirs` | Take theirs (right) |
| `:YDiffBoth` | Combine both |
| `:YDiffRestore` | Restore original with markers |
| `:YDiffPick` | File picker (requires snacks.nvim) |

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

## Credits

Original [vim-diffconflicts](https://github.com/whiteinge/diffconflicts) by **Seth House**.

Watch his explanation: [YouTube](https://www.youtube.com/watch?v=Pxgl3Wtf78Y)

## License

BSD 3-Clause — see [LICENSE](LICENSE)
