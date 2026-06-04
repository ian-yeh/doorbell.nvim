if vim.g.loaded_doorbell then return end
vim.g.loaded_doorbell = 1

require("doorbell").setup()
