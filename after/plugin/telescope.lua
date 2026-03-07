local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fg', builtin.git_files, { desc = 'Telescope git files' })
vim.keymap.set('n', '<leader>ss', builtin.grep_string, { desc = 'Telescope git search'});
vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'Telescope live grep search'});
