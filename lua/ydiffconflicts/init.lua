-- ydiffconflicts.nvim - A better Vimdiff mergetool
local M = {}

local function has_conflicts()
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line:match("^<<<<<<< ") then return true end
  end
  return false
end

local function get_conflict_style()
  local style = vim.trim(vim.fn.system("git config --get merge.conflictStyle"))
  return (style == "diff3" or style == "zdiff3") and style or "merge"
end

local function diffconflicts()
  local orig_buf = vim.api.nvim_get_current_buf()
  local orig_ft = vim.bo.filetype
  local orig_lines = vim.api.nvim_buf_get_lines(orig_buf, 0, -1, false)
  local style = get_conflict_style()

  -- Right side (theirs)
  vim.cmd('rightb vsplit | enew')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, orig_lines)
  vim.api.nvim_buf_set_name(0, 'RCONFL')
  vim.bo.filetype = orig_ft
  vim.cmd.diffthis()
  vim.cmd('silent! g/^<<<<<<< /,/^=======\\r\\?$/d')
  vim.cmd('silent! g/^>>>>>>> /d')
  vim.bo.modifiable, vim.bo.readonly = false, true
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.buflisted = 'nofile', 'delete', false

  -- Left side (ours)
  vim.cmd.wincmd('p')
  vim.cmd.diffthis()
  if style == "diff3" or style == "zdiff3" then
    vim.cmd('silent! g/^||||||| \\?/,/^>>>>>>> /d')
  else
    vim.cmd('silent! g/^=======\\r\\?$/,/^>>>>>>> /d')
  end
  vim.cmd('silent! g/^<<<<<<< /d')
  vim.cmd.diffupdate()
end

local function find_buf(pattern)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b):match(pattern) then
      return b
    end
  end
end

local function show_history()
  local local_buf = find_buf("LOCAL")
  local base_buf = find_buf("BASE")
  local remote_buf = find_buf("REMOTE")

  if not (local_buf and base_buf and remote_buf) then
    vim.notify("Missing BASE, LOCAL, or REMOTE. Was nvim invoked by git mergetool?", vim.log.levels.WARN)
    return false
  end

  vim.cmd('tabnew | vsplit | vsplit | wincmd h | wincmd h')

  for i, buf in ipairs({ local_buf, base_buf, remote_buf }) do
    if i > 1 then vim.cmd.wincmd('l') end
    vim.api.nvim_set_current_buf(buf)
    vim.bo.modifiable, vim.bo.readonly = false, true
    vim.cmd.diffthis()
  end

  vim.cmd.wincmd('h') -- back to BASE
  return true
end

local function cmd_diff()
  if has_conflicts() then
    vim.notify("Resolve conflicts leftward then save. Use :cq to abort.", vim.log.levels.WARN)
    diffconflicts()
  else
    vim.notify("No conflict markers found.", vim.log.levels.WARN)
  end
end

local function cmd_with_history()
  if show_history() then
    vim.cmd('1tabn')
    if has_conflicts() then
      vim.notify("Resolve conflicts leftward then save. Use :cq to abort.", vim.log.levels.WARN)
      diffconflicts()
    end
  end
end

vim.api.nvim_create_user_command('YDiffConflicts', cmd_diff, {})
vim.api.nvim_create_user_command('YDiffConflictsShowHistory', show_history, {})
vim.api.nvim_create_user_command('YDiffConflictsWithHistory', cmd_with_history, {})

return M
