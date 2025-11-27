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

local MARKER_START = "^<<<<<<<" 
local MARKER_END = "^>>>>>>>"

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
-- Two-Way Diff View
--------------------------------------------------------------------------------

local function close_diff_view()
  -- Close the THEIRS buffer if it exists
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match("THEIRS$") then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end
  vim.cmd("diffoff!")
end

local function open_diff_view()
  if not has_conflicts() then
    vim.notify("No conflict markers in this file", vim.log.levels.WARN)
    return
  end

  -- Close any existing diff view first
  close_diff_view()

  local orig_buf = vim.api.nvim_get_current_buf()
  local orig_ft = vim.bo.filetype
  local orig_lines = vim.api.nvim_buf_get_lines(orig_buf, 0, -1, false)
  local style = get_conflict_style()

  -- Right side (theirs) - read only reference
  vim.cmd("rightb vsplit | enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, orig_lines)
  vim.api.nvim_buf_set_name(0, "THEIRS")
  vim.bo.filetype = orig_ft
  vim.cmd.diffthis()
  vim.cmd([[silent! g/^<<<<<<< /,/^=======\r\?$/d]])
  vim.cmd([[silent! g/^>>>>>>> /d]])
  vim.bo.modifiable = false
  vim.bo.readonly = true
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.buflisted = false

  -- Left side (ours) - this is what we edit
  vim.cmd.wincmd("p")
  vim.cmd.diffthis()
  if style == "diff3" or style == "zdiff3" then
    vim.cmd([[silent! g/^||||||| \?/,/^>>>>>>> /d]])
  else
    vim.cmd([[silent! g/^=======\r\?$/,/^>>>>>>> /d]])
  end
  vim.cmd([[silent! g/^<<<<<<< /d]])
  vim.cmd.diffupdate()

  vim.notify("Edit left (ours). Use :diffget to pull from right (theirs). :w to save.", vim.log.levels.INFO)
end

-- Take all changes from ours (left) or theirs (right)
local function choose_all(side)
  if side == "ours" then
    -- Already showing ours on left, just close diff
    close_diff_view()
    vim.notify("Kept ours", vim.log.levels.INFO)
  elseif side == "theirs" then
    -- Get everything from theirs
    vim.cmd("diffget")
    close_diff_view()
    vim.notify("Took theirs", vim.log.levels.INFO)
  elseif side == "both" then
    -- This is trickier - need to combine. For now, close and let user edit manually.
    close_diff_view()
    vim.notify("Edit manually to combine both versions", vim.log.levels.INFO)
  end
end

--------------------------------------------------------------------------------
-- Mark Resolved
--------------------------------------------------------------------------------

local function mark_resolved()
  local file = vim.fn.expand("%:p")
  
  -- Check if still in diff mode with THEIRS
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match("THEIRS$") then
      vim.notify("Close diff view first (:YDiffClose or resolve conflicts)", vim.log.levels.WARN)
      return
    end
  end

  -- Save the file first
  vim.cmd("silent write")
  
  vim.fn.system("git add " .. vim.fn.shellescape(file))
  vim.notify("Resolved: " .. vim.fn.fnamemodify(file, ":t"), vim.log.levels.INFO)
  
  -- Refresh quickfix
  populate_quickfix()
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------

local function start()
  if not populate_quickfix() then return end
  vim.cmd("copen")
  vim.cmd("cfirst")
  -- Auto-open diff view for the first file
  vim.cmd("wincmd p") -- go to file window
  open_diff_view()
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("YDiffList", start, { desc = "Open conflict list and start resolving" })
vim.api.nvim_create_user_command("YDiffOpen", open_diff_view, { desc = "Open two-way diff for current file" })
vim.api.nvim_create_user_command("YDiffClose", close_diff_view, { desc = "Close two-way diff view" })
vim.api.nvim_create_user_command("YDiffOurs", function() choose_all("ours") end, { desc = "Keep ours (left)" })
vim.api.nvim_create_user_command("YDiffTheirs", function() choose_all("theirs") end, { desc = "Take theirs (right)" })
vim.api.nvim_create_user_command("YDiffResolved", mark_resolved, { desc = "Mark file as resolved (git add)" })

-- Keymaps in diff mode
vim.api.nvim_create_autocmd("OptionSet", {
  group = vim.api.nvim_create_augroup("YDiffConflicts", { clear = true }),
  pattern = "diff",
  callback = function()
    if vim.v.option_new == "1" then
      local opts = { buffer = true, silent = true }
      vim.keymap.set("n", "<leader>co", "<cmd>YDiffOurs<cr>", opts)
      vim.keymap.set("n", "<leader>ct", "<cmd>YDiffTheirs<cr>", opts)
      vim.keymap.set("n", "<leader>cd", "<cmd>YDiffResolved<cr>", opts)
    end
  end,
})

return M
