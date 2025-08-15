vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
vim.o.number = true
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)
vim.o.undofile = true
vim.o.updatetime = 250
vim.o.splitright = true
vim.o.splitbelow = false
vim.o.scrolloff = 10
