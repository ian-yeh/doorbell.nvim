local M = {}

local current_win
local entries = {}
local open_float, render, render_entries, query

local WIDTH = 60
local ns = vim.api.nvim_create_namespace("doorbell")

vim.api.nvim_set_hl(0, "DoorbellRepo", { link = "Comment", default = true })
vim.api.nvim_set_hl(0, "DoorbellTitle", { bold = true, default = true })

local function dims(n_lines)
  local height = math.min(math.max(n_lines, 1) + 2, 20)
  return height, math.floor((vim.o.lines - height) / 2), math.floor((vim.o.columns - WIDTH) / 2)
end

local function truncate(line)
  if vim.fn.strdisplaywidth(line) <= WIDTH then
    return line
  end
  return vim.fn.strcharpart(line, 0, WIDTH - 1) .. "…"
end

function open_float(lines)
  local height, row, col = dims(#lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "doorbell"

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = WIDTH,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Doorbell ",
    title_pos = "center",
    footer = " <CR> open · r reload · q quit ",
    footer_pos = "center",
  })
  current_win = win
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  local opts = { noremap = true, silent = true, buffer = buf }
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    current_win = nil
  end
  vim.keymap.set("n", "q", close, opts)
  vim.keymap.set("n", "<Esc>", close, opts)

  vim.keymap.set("n", "r", function() query() end, opts)

  vim.keymap.set("n", "<CR>", function()
    local entry = entries[vim.api.nvim_win_get_cursor(0)[1]]
    if entry then
      vim.fn.jobstart({ "open", entry.url })
    end
  end, opts)
end

function render(lines)
  entries = {}
  if not (current_win and vim.api.nvim_win_is_valid(current_win)) then
    open_float(lines)
  else
    local height, row, col = dims(#lines)
    vim.api.nvim_win_set_config(current_win, {
      relative = "editor", width = WIDTH, height = height, row = row, col = col,
    })
  end
  local buf = vim.api.nvim_win_get_buf(current_win)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  return buf
end

function render_entries(items)
  local lines = {}
  for _, item in ipairs(items) do
    lines[#lines + 1] = truncate(item.repository.nameWithOwner .. "  " .. item.title)
  end

  local buf = render(lines)
  entries = items
  for i, item in ipairs(items) do
    local repo_len = #item.repository.nameWithOwner
    local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, true)[1]
    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
      end_col = math.min(repo_len, #line),
      hl_group = "DoorbellRepo",
    })
    if repo_len + 2 < #line then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, repo_len + 2, {
        end_col = #line,
        hl_group = "DoorbellTitle",
      })
    end
  end
end

local function preflight()
  if vim.fn.executable("gh") ~= 1 then
    return {
      "GitHub CLI (gh) not found on PATH.",
      "Install it: https://cli.github.com",
    }
  end

  vim.fn.system({ "gh", "auth", "status" })
  if vim.v.shell_error ~= 0 then
    return {
      "Not logged in to GitHub.",
      "Run: gh auth login",
    }
  end

  return nil
end

function query()
  render({ "Fetching PRs..." })

  vim.fn.jobstart(
    { "gh", "search", "prs", "--state", "open", "--review-requested", "@me",
      "--json", "url,title,repository" },
    {
      stdout_buffered = true,
      on_stdout = function(_, data)
        local raw = data and table.concat(data, "\n") or ""
        if raw:match("^%s*$") then return end
        local ok, items = pcall(vim.json.decode, raw)
        vim.schedule(function()
          if not ok or type(items) ~= "table" then
            render({ "Error: could not parse gh output." })
          elseif #items == 0 then
            render({ "No PRs requesting your review." })
          else
            render_entries(items)
          end
        end)
      end,
      on_stderr = function(_, data)
        if data and data[1] ~= "" then
          vim.schedule(function() render({ "Error: " .. table.concat(data, " ") }) end)
        end
      end,
    }
  )
end

function M.fetch()
  local problem = preflight()
  if problem then
    render(problem)
    return
  end
  query()
end

function M.setup()
  vim.api.nvim_create_user_command("Doorbell", M.fetch, {})
end

return M
