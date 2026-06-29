local M = {}

local current_win

local function open_float(lines)
  -- Replace any existing Doorbell float so windows don't stack
  if current_win and vim.api.nvim_win_is_valid(current_win) then
    vim.api.nvim_win_close(current_win, true)
  end

  local width = 60
  local height = math.min(#lines + 2, 20)
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "doorbell")

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Doorbell ",
    title_pos = "center",
  })
  current_win = win

  -- Conceal the " | <url>" tail so only "repo | title" shows. The URL stays in
  -- the buffer text, so <CR> can still extract it.
  vim.api.nvim_set_option_value("conceallevel", 3, { win = win })
  vim.api.nvim_set_option_value("concealcursor", "nvic", { win = win })
  vim.fn.matchadd("Conceal", [[\s*|\s*https://\S\+]], 10, -1, { conceal = "" })

  -- q or <Esc> closes
  local opts = { noremap = true, silent = true, buffer = buf }
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    current_win = nil
  end
  vim.keymap.set("n", "q", close, opts)
  vim.keymap.set("n", "<Esc>", close, opts)

  -- <CR> opens PR in browser
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local url = line:match("https://%S+")
    if url then
      vim.fn.jobstart({ "open", url }) -- macOS; use "xdg-open" on Linux
    end
  end, opts)
end

-- Returns nil if gh is usable, or a list of message lines explaining why not.
local function preflight()
  if vim.fn.executable("gh") ~= 1 then
    return {
      "GitHub CLI (gh) not found on PATH.",
      "Install it: https://cli.github.com",
    }
  end

  -- `gh auth status` exits non-zero when not logged in.
  vim.fn.system({ "gh", "auth", "status" })
  if vim.v.shell_error ~= 0 then
    return {
      "Not logged in to GitHub.",
      "Run: gh auth login",
    }
  end

  return nil
end

function M.fetch()
  local problem = preflight()
  if problem then
    open_float(problem)
    return
  end

  open_float({ "Fetching PRs..." })

  vim.fn.jobstart(
    { "gh", "search", "prs", "--state", "open", "--review-requested", "@me",
      "--json", "url,title,repository", "--jq",
      [[.[] | "\(.repository.nameWithOwner) | \(.title[:40]) | \(.url)"]] },
    {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data and #data > 0 then
          -- filter empty trailing lines
          local lines = vim.tbl_filter(function(l) return l ~= "" end, data)
          if #lines == 0 then lines = { "No PRs requesting your review." } end
          vim.schedule(function() open_float(lines) end)
        end
      end,
      on_stderr = function(_, data)
        if data and data[1] ~= "" then
          vim.schedule(function() open_float({ "Error: " .. table.concat(data, " ") }) end)
        end
      end,
    }
  )
end

function M.setup()
  vim.api.nvim_create_user_command("Doorbell", M.fetch, {})
end

return M
