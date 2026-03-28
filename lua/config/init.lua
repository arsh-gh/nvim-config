vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
vim.o.number = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)
vim.o.undofile = true
vim.o.updatetime = 250
vim.o.splitright = true
vim.o.splitbelow = false
vim.o.scrolloff = 10
vim.opt.expandtab = true
