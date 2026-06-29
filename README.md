# doorbell.nvim

A tiny Neovim plugin that shows the GitHub pull requests waiting on **your**
review in a floating window.

It shells out to the [GitHub CLI](https://cli.github.com) (`gh`), so there are no
tokens to configure: if you're already logged in to `gh`, it just works.

## Requirements

- Neovim 0.7+ (uses `vim.keymap.set` and `nvim_create_user_command`)
- [`gh`](https://cli.github.com) installed and authenticated (`gh auth login`)
- macOS for the "open in browser" action (uses `open`; see [Notes](#notes))

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "ian-yeh/doorbell.nvim" }
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use "ian-yeh/doorbell.nvim"
```

The plugin self-registers its command on load, so no `setup()` call is required.

## Configuration

`setup()` is optional. Call it to change which PRs Doorbell lists:

```lua
require("doorbell").setup({
  query = "review_requested", -- default
})
```

`query` accepts:

| Value              | PRs shown                          |
| ------------------ | ---------------------------------- |
| `review_requested` | requesting your review (default)   |
| `authored`         | you opened                         |
| `assigned`         | assigned to you                    |
| `mentions`         | you're mentioned in               |

An unknown value warns and falls back to the default.

## Usage

Run the command:

```vim
:Doorbell
```

A floating window opens listing every open PR that has requested your review,
one per line as `repo | title | url`.

| Key     | Action                          |
| ------- | ------------------------------- |
| `<CR>`  | Open the PR under the cursor in your browser |
| `q`     | Close the window                |
| `<Esc>` | Close the window                |

Before querying, Doorbell checks that `gh` is installed and that you're logged
in, showing a helpful message in the float if either is missing.

## How it works

Doorbell runs:

```sh
gh search prs --state open --review-requested @me --json url,title,repository
```

and formats the results into the floating window. The query runs
asynchronously via `jobstart`, so it never blocks the editor.

## Notes

- **Linux/Windows:** the `<CR>` browser action uses macOS's `open`. On Linux,
  change `open` to `xdg-open` in `lua/doorbell/init.lua` (line is marked with a
  comment).
- See `:help doorbell` for the bundled help doc.

## License

MIT
