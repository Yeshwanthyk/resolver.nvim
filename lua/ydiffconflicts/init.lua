-- ydiffconflicts.nvim - Two-way diff for Git merge conflicts
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
-- Marker Extraction (state machine)
--------------------------------------------------------------------------------

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
-- Two-Way Diff View
--------------------------------------------------------------------------------

-- Track the THEIRS buffer so we can clean it up
local theirs_bufnr = nil
local theirs_winnr = nil

local function close_diff_view()
  vim.cmd("diffoff!")
  
  -- Close THEIRS window and buffer
  if theirs_winnr and vim.api.nvim_win_is_valid(theirs_winnr) then
    vim.api.nvim_win_close(theirs_winnr, true)
  end
  if theirs_bufnr and vim.api.nvim_buf_is_valid(theirs_bufnr) then
    vim.api.nvim_buf_delete(theirs_bufnr, { force = true })
  end
  theirs_bufnr = nil
  theirs_winnr = nil
end

local function open_diff_view()
  -- Close any existing diff first
  close_diff_view()
  
  local orig_buf = vim.api.nvim_get_current_buf()
  local orig_win = vim.api.nvim_get_current_win()
  local orig_file = vim.api.nvim_buf_get_name(orig_buf)
  local orig_ft = vim.bo[orig_buf].filetype
  local orig_lines = vim.api.nvim_buf_get_lines(orig_buf, 0, -1, false)

  if not has_conflicts(orig_buf) then
    vim.notify("No conflict markers in this file", vim.log.levels.WARN)
    return
  end

  -- Extract versions
  local ours_lines = extract_ours(orig_lines)
  local theirs_lines = extract_theirs(orig_lines)

  -- Set left buffer to OURS (stripped markers)
  vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, ours_lines)
  vim.cmd.diffthis()

  -- Create THEIRS buffer on right
  vim.cmd("rightbelow vsplit")
  theirs_winnr = vim.api.nvim_get_current_win()
  vim.cmd("enew")
  theirs_bufnr = vim.api.nvim_get_current_buf()
  
  vim.api.nvim_buf_set_lines(theirs_bufnr, 0, -1, false, theirs_lines)
  vim.api.nvim_buf_set_name(theirs_bufnr, orig_file .. " [THEIRS]")
  vim.bo[theirs_bufnr].filetype = orig_ft
  vim.bo[theirs_bufnr].buftype = "nofile"
  vim.bo[theirs_bufnr].bufhidden = "wipe"
  vim.bo[theirs_bufnr].buflisted = false
  vim.bo[theirs_bufnr].modifiable = false
  vim.cmd.diffthis()

  -- Go back to OURS (left)
  vim.api.nvim_set_current_win(orig_win)
  vim.cmd("diffupdate")

  vim.notify("OURS (left, edit) | THEIRS (right, ref). :diffget to pull. :w saves.", vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Resolution
--------------------------------------------------------------------------------

local function choose_side(side)
  if side == "ours" then
    close_diff_view()
    vim.notify("Kept OURS", vim.log.levels.INFO)
  elseif side == "theirs" then
    vim.cmd("%diffget")
    close_diff_view()
    vim.notify("Took THEIRS", vim.log.levels.INFO)
  elseif side == "both" then
    vim.cmd("earlier 1f")
    close_diff_view()
    vim.notify("Restored original - edit manually", vim.log.levels.INFO)
  end
end

local function mark_resolved()
  close_diff_view()
  
  local file = vim.fn.expand("%:p")
  if has_conflicts() then
    vim.notify("File still has conflict markers!", vim.log.levels.ERROR)
    return
  end

  vim.cmd("silent write")
  vim.fn.system("git add " .. vim.fn.shellescape(file))
  vim.notify("✓ " .. vim.fn.fnamemodify(file, ":t"), vim.log.levels.INFO)
  populate_quickfix()
end

local function next_conflict_file()
  close_diff_view()
  vim.cmd("cnext")
  vim.schedule(function()
    if has_conflicts() then
      open_diff_view()
    end
  end)
end

local function prev_conflict_file()
  close_diff_view()
  vim.cmd("cprev")
  vim.schedule(function()
    if has_conflicts() then
      open_diff_view()
    end
  end)
end

--------------------------------------------------------------------------------
-- Main Entry
--------------------------------------------------------------------------------

local function start()
  if not populate_quickfix() then return end
  
  vim.cmd("copen")
  vim.cmd("wincmd k")
  vim.cmd("cfirst")
  
  vim.schedule(function()
    if has_conflicts() then
      open_diff_view()
    end
  end)
  
  vim.notify("Resolve conflicts. :YDiffNext/:YDiffPrev to navigate. :cq to abort.", vim.log.levels.INFO)
end

local function abort()
  close_diff_view()
  vim.cmd("cclose")
  vim.cmd("cq")  -- Exit with error code - tells git mergetool to abort
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("YDiffList", start, { desc = "Start conflict resolution" })
vim.api.nvim_create_user_command("YDiff", open_diff_view, { desc = "Open two-way diff" })
vim.api.nvim_create_user_command("YDiffClose", close_diff_view, { desc = "Close diff view" })
vim.api.nvim_create_user_command("YDiffOurs", function() choose_side("ours") end, { desc = "Keep OURS" })
vim.api.nvim_create_user_command("YDiffTheirs", function() choose_side("theirs") end, { desc = "Take THEIRS" })
vim.api.nvim_create_user_command("YDiffBoth", function() choose_side("both") end, { desc = "Restore original" })
vim.api.nvim_create_user_command("YDiffResolved", mark_resolved, { desc = "Mark resolved (git add)" })
vim.api.nvim_create_user_command("YDiffNext", next_conflict_file, { desc = "Next conflict file" })
vim.api.nvim_create_user_command("YDiffPrev", prev_conflict_file, { desc = "Prev conflict file" })
vim.api.nvim_create_user_command("YDiffAbort", abort, { desc = "Abort merge" })

-- Legacy aliases
vim.api.nvim_create_user_command("YDiffConflicts", open_diff_view, {})
vim.api.nvim_create_user_command("YDiffConflictsWithHistory", open_diff_view, {})
vim.api.nvim_create_user_command("YDiffOpen", open_diff_view, {})

-- Keymaps when in diff mode
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
      vim.keymap.set("n", "]q", "<cmd>YDiffNext<cr>", opts)
      vim.keymap.set("n", "[q", "<cmd>YDiffPrev<cr>", opts)
    end
  end,
})

return M
