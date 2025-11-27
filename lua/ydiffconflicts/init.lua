-- ydiffconflicts.nvim - Two-way diff for Git merge conflicts

local MARKER_START = "^<<<<<<< "
local MARKER_ANCESTOR = "^||||||| "
local MARKER_MIDDLE = "^=======$"
local MARKER_END = "^>>>>>>> "

local orig_lines = nil

--------------------------------------------------------------------------------
-- Extraction
--------------------------------------------------------------------------------

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
-- Diff View
--------------------------------------------------------------------------------

local function close_diff()
  local found = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match("%[THEIRS%]$") then
      found = true
      local wins = vim.fn.win_findbuf(buf)
      for _, win in ipairs(wins) do
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      end
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end
  end
  if found then vim.cmd("diffoff!") end
end

local function open_diff()
  local filepath = vim.fn.expand("%:p")
  local lines = vim.fn.readfile(filepath)
  
  local has_conflicts = false
  for _, line in ipairs(lines) do
    if line:match(MARKER_START) then has_conflicts = true; break end
  end
  if not has_conflicts then
    vim.notify("No conflict markers", vim.log.levels.WARN)
    return
  end

  orig_lines = lines
  local ft = vim.bo.filetype

  -- Left: OURS
  vim.api.nvim_buf_set_lines(0, 0, -1, false, extract_ours(lines))
  vim.cmd("diffthis")

  -- Right: THEIRS
  vim.cmd("rightbelow vsplit | enew")
  local theirs_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(theirs_buf, 0, -1, false, extract_theirs(lines))
  vim.bo[theirs_buf].buftype = "nofile"
  vim.bo[theirs_buf].bufhidden = "wipe"
  vim.bo[theirs_buf].filetype = ft
  pcall(vim.api.nvim_buf_set_name, theirs_buf, "[THEIRS]")
  vim.bo[theirs_buf].modifiable = false
  vim.cmd("diffthis")

  -- Back to OURS and ensure diff is active
  vim.cmd("wincmd h")
  vim.cmd("diffthis")
  
  -- Force diff update after a tick
  vim.schedule(function()
    vim.cmd("diffupdate")
  end)
  
  local o = { buffer = true, silent = true }
  vim.keymap.set("n", "<leader>mo", "<cmd>YDiffOurs<cr>", o)
  vim.keymap.set("n", "<leader>mt", "<cmd>YDiffTheirs<cr>", o)
  vim.keymap.set("n", "<leader>mb", "<cmd>YDiffBoth<cr>", o)
  vim.keymap.set("n", "<leader>mr", "<cmd>YDiffRestore<cr>", o)
  vim.keymap.set("n", "<leader>mp", "<cmd>YDiffPick<cr>", o)
  
  vim.notify("OURS | THEIRS. <leader>mo/mt/mb/mr/mp", vim.log.levels.INFO)
end

local function choose(side)
  if not orig_lines then
    vim.notify("Run :YDiff first", vim.log.levels.WARN)
    return
  end
  if side == "ours" then
    vim.notify("Kept OURS", vim.log.levels.INFO)
  elseif side == "theirs" then
    vim.cmd("%diffget | diffupdate")
    vim.notify("Took THEIRS", vim.log.levels.INFO)
  elseif side == "both" then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, extract_both(orig_lines))
    vim.cmd("diffupdate")
    vim.notify("Combined OURS + THEIRS", vim.log.levels.INFO)
  end
end

local function restore()
  if not orig_lines then
    vim.notify("Nothing to restore", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, orig_lines)
  vim.cmd("diffupdate")
  vim.notify("Restored original", vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Picker
--------------------------------------------------------------------------------

local function get_conflicted_files()
  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  if root == "" then return {} end
  local output = vim.fn.system("git diff --name-only --diff-filter=U 2>/dev/null")
  local files = {}
  for file in output:gmatch("[^\n]+") do
    if file ~= "" then table.insert(files, { file = root .. "/" .. file, text = file }) end
  end
  return files
end

local function open_picker()
  local ok, Snacks = pcall(require, "snacks")
  if not ok then
    vim.notify("snacks.nvim required for picker", vim.log.levels.ERROR)
    return
  end

  local files = get_conflicted_files()
  if #files == 0 then
    vim.notify("No conflicted files", vim.log.levels.INFO)
    return
  end

  Snacks.picker({
    title = "Conflicts",
    items = files,
    format = function(item) return { { item.text, "SnacksPickerFile" } } end,
    confirm = function(picker, item)
      picker:close()
      close_diff()
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
      vim.schedule(open_diff)
    end,
  })
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("YDiff", open_diff, {})
vim.api.nvim_create_user_command("YDiffClose", close_diff, {})
vim.api.nvim_create_user_command("YDiffOurs", function() choose("ours") end, {})
vim.api.nvim_create_user_command("YDiffTheirs", function() choose("theirs") end, {})
vim.api.nvim_create_user_command("YDiffBoth", function() choose("both") end, {})
vim.api.nvim_create_user_command("YDiffRestore", restore, {})
vim.api.nvim_create_user_command("YDiffPick", open_picker, {})

return {}
