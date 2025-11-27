-- ydiffconflicts.nvim - Two-way diff for Git merge conflicts
local M = {}

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

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
-- Conflict Markers
--------------------------------------------------------------------------------

local MARKER_START = "^<<<<<<< "
local MARKER_ANCESTOR = "^||||||| "
local MARKER_MIDDLE = "^=======$"
local MARKER_END = "^>>>>>>> "

local function file_has_conflicts(filepath)
  local f = io.open(filepath, "r")
  if not f then return false end
  for line in f:lines() do
    if line:match(MARKER_START) then
      f:close()
      return true
    end
  end
  f:close()
  return false
end

local function count_conflicts(filepath)
  local f = io.open(filepath, "r")
  if not f then return 0 end
  local count = 0
  for line in f:lines() do
    if line:match(MARKER_START) then count = count + 1 end
  end
  f:close()
  return count
end

local function extract_ours(lines)
  local result = {}
  local state = "NORMAL"
  for _, line in ipairs(lines) do
    if line:match(MARKER_START) then state = "OURS"
    elseif line:match(MARKER_ANCESTOR) then state = "BASE"
    elseif line:match(MARKER_MIDDLE) then state = "THEIRS"
    elseif line:match(MARKER_END) then state = "NORMAL"
    elseif state == "NORMAL" or state == "OURS" then table.insert(result, line)
    end
  end
  return result
end

local function extract_theirs(lines)
  local result = {}
  local state = "NORMAL"
  for _, line in ipairs(lines) do
    if line:match(MARKER_START) then state = "OURS"
    elseif line:match(MARKER_ANCESTOR) then state = "BASE"
    elseif line:match(MARKER_MIDDLE) then state = "THEIRS"
    elseif line:match(MARKER_END) then state = "NORMAL"
    elseif state == "NORMAL" or state == "THEIRS" then table.insert(result, line)
    end
  end
  return result
end

local function extract_both(lines)
  local result = {}
  local state = "NORMAL"
  local ours_block, theirs_block = {}, {}
  for _, line in ipairs(lines) do
    if line:match(MARKER_START) then
      state = "OURS"
      ours_block, theirs_block = {}, {}
    elseif line:match(MARKER_ANCESTOR) then state = "BASE"
    elseif line:match(MARKER_MIDDLE) then state = "THEIRS"
    elseif line:match(MARKER_END) then
      for _, l in ipairs(ours_block) do table.insert(result, l) end
      for _, l in ipairs(theirs_block) do table.insert(result, l) end
      state = "NORMAL"
    elseif state == "NORMAL" then table.insert(result, line)
    elseif state == "OURS" then table.insert(ours_block, line)
    elseif state == "THEIRS" then table.insert(theirs_block, line)
    end
  end
  return result
end

--------------------------------------------------------------------------------
-- Quickfix
--------------------------------------------------------------------------------

local function populate_quickfix()
  local files = get_conflicted_files()
  if #files == 0 then
    vim.notify("All conflicts resolved!", vim.log.levels.INFO)
    vim.fn.setqflist({}, "r")
    return false
  end

  local items = {}
  local resolved = 0
  for _, filepath in ipairs(files) do
    local has_markers = file_has_conflicts(filepath)
    if has_markers then
      local count = count_conflicts(filepath)
      local f = io.open(filepath, "r")
      local lnum = 1
      if f then
        for line in f:lines() do
          if line:match(MARKER_START) then break end
          lnum = lnum + 1
        end
        f:close()
      end
      table.insert(items, { filename = filepath, lnum = lnum, text = count .. " conflict" .. (count > 1 and "s" or "") })
    else
      resolved = resolved + 1
      table.insert(items, { filename = filepath, lnum = 1, text = "✓ resolved" })
    end
  end

  vim.fn.setqflist(items, "r")
  vim.fn.setqflist({}, "a", { title = string.format("Conflicts (%d/%d done)", resolved, #items) })
  return true
end

--------------------------------------------------------------------------------
-- Two-Way Diff
--------------------------------------------------------------------------------

local theirs_win = nil
local theirs_buf = nil
local ours_win = nil

local function close_diff()
  vim.cmd("diffoff!")
  if theirs_win and vim.api.nvim_win_is_valid(theirs_win) then
    vim.api.nvim_win_close(theirs_win, true)
  end
  if theirs_buf and vim.api.nvim_buf_is_valid(theirs_buf) then
    vim.api.nvim_buf_delete(theirs_buf, { force = true })
  end
  theirs_win, theirs_buf = nil, nil
end

local function open_diff()
  close_diff()
  
  local filepath = vim.fn.expand("%:p")
  if filepath == "" or not file_has_conflicts(filepath) then
    vim.notify("No conflicts in this file", vim.log.levels.WARN)
    return
  end

  -- Read file fresh from disk
  local lines = vim.fn.readfile(filepath)
  local ours = extract_ours(lines)
  local theirs = extract_theirs(lines)
  local ft = vim.bo.filetype

  -- Set current buffer to OURS
  ours_win = vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, ours)
  vim.cmd("diffthis")

  -- Create THEIRS split
  vim.cmd("rightbelow vsplit")
  vim.cmd("enew")
  theirs_win = vim.api.nvim_get_current_win()
  theirs_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(theirs_buf, 0, -1, false, theirs)
  vim.api.nvim_buf_set_name(theirs_buf, "[THEIRS]")
  vim.bo[theirs_buf].buftype = "nofile"
  vim.bo[theirs_buf].bufhidden = "wipe"
  vim.bo[theirs_buf].modifiable = false
  vim.bo[theirs_buf].filetype = ft
  vim.cmd("diffthis")

  -- Back to OURS
  vim.api.nvim_set_current_win(ours_win)
  vim.notify("OURS (left) | THEIRS (right) — :diffget / do to pull", vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function choose(side)
  local filepath = vim.fn.expand("%:p")
  if side == "ours" then
    vim.notify("Kept OURS", vim.log.levels.INFO)
  elseif side == "theirs" then
    vim.cmd("%diffget")
    vim.cmd("diffupdate")
    vim.notify("Took THEIRS", vim.log.levels.INFO)
  elseif side == "both" then
    local lines = vim.fn.readfile(filepath)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, extract_both(lines))
    vim.cmd("diffupdate")
    vim.notify("Combined OURS + THEIRS", vim.log.levels.INFO)
  end
end

local function mark_resolved()
  close_diff()
  local file = vim.fn.expand("%:p")
  vim.cmd("write")
  vim.fn.system("git add " .. vim.fn.shellescape(file))
  vim.notify("✓ " .. vim.fn.fnamemodify(file, ":t"), vim.log.levels.INFO)
  populate_quickfix()
end

local function unresolve()
  close_diff()
  local file = vim.fn.expand("%:p")
  vim.fn.system("git checkout --conflict=merge " .. vim.fn.shellescape(file))
  vim.cmd("edit!")
  populate_quickfix()
  vim.schedule(open_diff)
end

local function go_file(cmd)
  close_diff()
  -- Focus quickfix, then go to window above it
  vim.cmd("copen | wincmd k")
  local ok = pcall(vim.cmd, cmd)
  if ok then vim.schedule(open_diff) end
end

local function go_next() go_file("cnext") end
local function go_prev() go_file("cprev") end

local function start()
  if not populate_quickfix() then return end
  vim.cmd("copen | wincmd k | cfirst")
  vim.schedule(open_diff)
end

local function abort()
  close_diff()
  vim.cmd("cclose | cq")
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("YDiffList", start, {})
vim.api.nvim_create_user_command("YDiff", open_diff, {})
vim.api.nvim_create_user_command("YDiffClose", close_diff, {})
vim.api.nvim_create_user_command("YDiffOurs", function() choose("ours") end, {})
vim.api.nvim_create_user_command("YDiffTheirs", function() choose("theirs") end, {})
vim.api.nvim_create_user_command("YDiffBoth", function() choose("both") end, {})
vim.api.nvim_create_user_command("YDiffResolved", mark_resolved, {})
vim.api.nvim_create_user_command("YDiffUnresolve", unresolve, {})
vim.api.nvim_create_user_command("YDiffNext", go_next, {})
vim.api.nvim_create_user_command("YDiffPrev", go_prev, {})
vim.api.nvim_create_user_command("YDiffAbort", abort, {})

-- Legacy
vim.api.nvim_create_user_command("YDiffConflicts", open_diff, {})
vim.api.nvim_create_user_command("YDiffConflictsWithHistory", open_diff, {})

-- Keymaps in diff mode
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "diff",
  callback = function()
    if vim.v.option_new == "1" then
      local o = { buffer = true, silent = true }
      vim.keymap.set("n", "<leader>co", "<cmd>YDiffOurs<cr>", o)
      vim.keymap.set("n", "<leader>ct", "<cmd>YDiffTheirs<cr>", o)
      vim.keymap.set("n", "<leader>cb", "<cmd>YDiffBoth<cr>", o)
      vim.keymap.set("n", "<leader>cw", "<cmd>YDiffResolved<cr>", o)
      vim.keymap.set("n", "]q", "<cmd>YDiffNext<cr>", o)
      vim.keymap.set("n", "[q", "<cmd>YDiffPrev<cr>", o)
    end
  end,
})

return M
