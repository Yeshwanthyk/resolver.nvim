-- ydiffconflicts.nvim - Two-way and three-way diff for Git merge conflicts
-- Original concept by Seth House (vim-diffconflicts)
local M = {}

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local function get_conflict_style()
  local style = vim.trim(vim.fn.system("git config --get merge.conflictStyle"))
  return (style == "diff3" or style == "zdiff3") and style or "merge"
end

local function get_git_root()
  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  return root ~= "" and root or nil
end

local function get_conflicted_files()
  local root = get_git_root()
  if not root then return {} end
  local output = vim.fn.system("git diff --name-only --diff-filter=U 2>/dev/null")
  local files = {}
  for file in output:gmatch("[^\n]+") do
    if file ~= "" then
      table.insert(files, root .. "/" .. file)
    end
  end
  return files
end

--------------------------------------------------------------------------------
-- Conflict Detection
--------------------------------------------------------------------------------

local MARKER_START = "^<<<<<<< "
local MARKER_ANCESTOR = "^||||||| "
local MARKER_MIDDLE = "^=======$"
local MARKER_END = "^>>>>>>> "

local function has_conflicts(bufnr)
  bufnr = bufnr or 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line:match(MARKER_START) then return true end
  end
  return false
end

local function count_conflicts_in_file(filepath)
  local f = io.open(filepath, "r")
  if not f then return 0 end
  local count = 0
  for line in f:lines() do
    if line:match(MARKER_START) then count = count + 1 end
  end
  f:close()
  return count
end

--------------------------------------------------------------------------------
-- Quickfix List
--------------------------------------------------------------------------------

local function populate_quickfix()
  local files = get_conflicted_files()
  if #files == 0 then
    vim.notify("No conflicted files found", vim.log.levels.INFO)
    return false
  end

  local items = {}
  for _, filepath in ipairs(files) do
    local count = count_conflicts_in_file(filepath)
    local f = io.open(filepath, "r")
    if f then
      local lnum = 1
      for line in f:lines() do
        if line:match(MARKER_START) then
          table.insert(items, {
            filename = filepath,
            lnum = lnum,
            text = count .. " conflict" .. (count > 1 and "s" or ""),
          })
          break
        end
        lnum = lnum + 1
      end
      f:close()
    end
  end

  vim.fn.setqflist(items, "r")
  vim.fn.setqflist({}, "a", { title = "Git Conflicts (" .. #items .. " files)" })
  return true
end

--------------------------------------------------------------------------------
-- Two-Way Diff View (OURS vs THEIRS)
--------------------------------------------------------------------------------

local function close_diff_view()
  -- Close THEIRS/BASE buffers if they exist
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match("THEIRS$") or name:match("BASE$") then
        local wins = vim.fn.win_findbuf(buf)
        for _, win in ipairs(wins) do
          vim.api.nvim_win_close(win, true)
        end
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end
  vim.cmd("diffoff!")
end

-- State machine for parsing conflict markers
-- States: NORMAL, OURS, BASE, THEIRS
local function extract_ours(lines)
  local result = {}
  local state = "NORMAL"
  
  for _, line in ipairs(lines) do
    if line:match(MARKER_START) then
      state = "OURS"
    elseif line:match(MARKER_ANCESTOR) then
      state = "BASE"
    elseif line:match(MARKER_MIDDLE) then
      state = "THEIRS"
    elseif line:match(MARKER_END) then
      state = "NORMAL"
    elseif state == "NORMAL" or state == "OURS" then
      table.insert(result, line)
    end
  end
  return result
end

local function extract_theirs(lines)
  local result = {}
  local state = "NORMAL"
  
  for _, line in ipairs(lines) do
    if line:match(MARKER_START) then
      state = "OURS"
    elseif line:match(MARKER_ANCESTOR) then
      state = "BASE"
    elseif line:match(MARKER_MIDDLE) then
      state = "THEIRS"
    elseif line:match(MARKER_END) then
      state = "NORMAL"
    elseif state == "NORMAL" or state == "THEIRS" then
      table.insert(result, line)
    end
  end
  return result
end

local function create_scratch_buf(name, lines, filetype)
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].filetype = filetype
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  return buf
end

local function open_two_way_diff()
  if not has_conflicts() then
    vim.notify("No conflict markers in this file", vim.log.levels.WARN)
    return
  end

  close_diff_view()

  local orig_buf = vim.api.nvim_get_current_buf()
  local orig_file = vim.api.nvim_buf_get_name(orig_buf)
  local orig_ft = vim.bo.filetype
  local orig_lines = vim.api.nvim_buf_get_lines(orig_buf, 0, -1, false)
  local style = get_conflict_style()

  local ours_lines = extract_ours(orig_lines)
  local theirs_lines = extract_theirs(orig_lines)

  -- Replace current buffer content with OURS (stripped of markers)
  vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, ours_lines)
  vim.cmd.diffthis()

  -- Right side: THEIRS (read-only)
  vim.cmd("rightb vsplit")
  create_scratch_buf(orig_file .. " [THEIRS]", theirs_lines, orig_ft)
  vim.cmd.diffthis()

  -- Go back to left (ours)
  vim.cmd.wincmd("p")
  vim.cmd("diffupdate")

  vim.notify("Left=OURS (edit), Right=THEIRS (ref). :diffget to pull. :w to save.", vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Three-Way Diff View (OURS | BASE | THEIRS)
--------------------------------------------------------------------------------

local function open_three_way_diff()
  if not has_conflicts() then
    vim.notify("No conflict markers in this file", vim.log.levels.WARN)
    return
  end

  local style = get_conflict_style()
  if style ~= "diff3" and style ~= "zdiff3" then
    vim.notify("Three-way diff requires merge.conflictStyle=diff3 or zdiff3", vim.log.levels.WARN)
    open_two_way_diff()
    return
  end

  close_diff_view()

  local orig_buf = vim.api.nvim_get_current_buf()
  local orig_file = vim.api.nvim_buf_get_name(orig_buf)
  local orig_ft = vim.bo.filetype
  local orig_lines = vim.api.nvim_buf_get_lines(orig_buf, 0, -1, false)

  local ours_lines = extract_ours(orig_lines)
  local theirs_lines = extract_theirs(orig_lines)

  -- Replace current buffer with OURS
  vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, ours_lines)
  vim.cmd.diffthis()

  -- Right side: THEIRS
  vim.cmd("rightb vsplit")
  create_scratch_buf(orig_file .. " [THEIRS]", theirs_lines, orig_ft)
  vim.cmd.diffthis()

  -- Go back to OURS
  vim.cmd.wincmd("p")
  vim.cmd("diffupdate")

  vim.notify("Left=OURS (edit), Right=THEIRS (ref). :diffget to pull. :w to save.", vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Resolution helpers
--------------------------------------------------------------------------------

local function choose_side(side)
  if side == "ours" then
    vim.cmd("diffoff!")
    close_diff_view()
    vim.notify("Kept OURS", vim.log.levels.INFO)
  elseif side == "theirs" then
    vim.cmd("%diffget")
    vim.cmd("diffoff!")
    close_diff_view()
    vim.notify("Took THEIRS", vim.log.levels.INFO)
  elseif side == "both" then
    -- Undo the extraction - user needs to resolve manually
    vim.cmd("earlier 1f")
    close_diff_view()
    vim.notify("Restored original. Edit manually to combine.", vim.log.levels.INFO)
  end
end

local function mark_resolved()
  local file = vim.fn.expand("%:p")
  
  -- Close diff if still open
  close_diff_view()

  -- Check for remaining markers
  if has_conflicts() then
    vim.notify("File still has conflict markers!", vim.log.levels.ERROR)
    return
  end

  vim.cmd("silent write")
  vim.fn.system("git add " .. vim.fn.shellescape(file))
  vim.notify("Resolved: " .. vim.fn.fnamemodify(file, ":t"), vim.log.levels.INFO)
  populate_quickfix()
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------

local function start()
  if not populate_quickfix() then return end
  
  -- Open quickfix
  vim.cmd("copen")
  vim.cmd("wincmd k")  -- Move to window above quickfix
  
  -- Go to first conflict file
  vim.cmd("cfirst")
  
  -- Schedule diff view to open after buffer is loaded
  vim.schedule(function()
    open_two_way_diff()
  end)
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("YDiffList", start, { desc = "Open conflict list and start resolving" })
vim.api.nvim_create_user_command("YDiff", open_two_way_diff, { desc = "Open two-way diff (OURS vs THEIRS)" })
vim.api.nvim_create_user_command("YDiff3", open_three_way_diff, { desc = "Open three-way diff (OURS | BASE | THEIRS)" })
vim.api.nvim_create_user_command("YDiffClose", close_diff_view, { desc = "Close diff view" })
vim.api.nvim_create_user_command("YDiffOurs", function() choose_side("ours") end, { desc = "Keep OURS" })
vim.api.nvim_create_user_command("YDiffTheirs", function() choose_side("theirs") end, { desc = "Take THEIRS" })
vim.api.nvim_create_user_command("YDiffBoth", function() choose_side("both") end, { desc = "Restore original to combine manually" })
vim.api.nvim_create_user_command("YDiffResolved", mark_resolved, { desc = "Mark resolved (git add)" })

-- Legacy aliases
vim.api.nvim_create_user_command("YDiffConflicts", open_two_way_diff, {})
vim.api.nvim_create_user_command("YDiffConflictsWithHistory", open_two_way_diff, {})
vim.api.nvim_create_user_command("YDiffOpen", open_two_way_diff, {})

-- Auto keymaps when diff mode is active
vim.api.nvim_create_autocmd("OptionSet", {
  group = vim.api.nvim_create_augroup("YDiffConflicts", { clear = true }),
  pattern = "diff",
  callback = function()
    if vim.v.option_new == "1" then
      local opts = { buffer = true, silent = true }
      vim.keymap.set("n", "<leader>co", "<cmd>YDiffOurs<cr>", opts)
      vim.keymap.set("n", "<leader>ct", "<cmd>YDiffTheirs<cr>", opts)
      vim.keymap.set("n", "<leader>cb", "<cmd>YDiffBoth<cr>", opts)
      vim.keymap.set("n", "<leader>cw", "<cmd>YDiffResolved<cr>", opts)
    end
  end,
})

return M
