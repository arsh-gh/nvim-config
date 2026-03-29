---@brief
---
--- https://clangd.llvm.org/installation.html
---
--- - **NOTE:** Clang >= 11 is recommended! See [#23](https://github.com/neovim/nvim-lspconfig/issues/23).
--- - If `compile_commands.json` lives in a build directory, you should
---   symlink it to the root of your source tree.
---   ```
---   ln -s /path/to/myproject/build/compile_commands.json /path/to/myproject/
---   ```
--- - clangd relies on a [JSON compilation database](https://clang.llvm.org/docs/JSONCompilationDatabase.html)
---   specified as compile_commands.json, see https://clangd.llvm.org/installation#compile_commandsjson

-- https://clangd.llvm.org/extensions.html#switch-between-sourceheader
local function switch_source_header(bufnr, client)
    local method_name = "textDocument/switchSourceHeader"
    ---@diagnostic disable-next-line:param-type-mismatch
    if not client or not client:supports_method(method_name) then
        return vim.notify(
            ("method %s is not supported by any servers active on the current buffer"):format(method_name)
        )
    end
    local params = vim.lsp.util.make_text_document_params(bufnr)
    ---@diagnostic disable-next-line:param-type-mismatch
    client:request(
        method_name,
        params,
        function(err, result)
            if err then
                error(tostring(err))
            end
            if not result then
                vim.notify("corresponding file cannot be determined")
                return
            end
            vim.cmd.edit(vim.uri_to_fname(result))
        end,
        bufnr
    )
end

local function symbol_info(bufnr, client)
    local method_name = "textDocument/symbolInfo"
    ---@diagnostic disable-next-line:param-type-mismatch
    if not client or not client:supports_method(method_name) then
        return vim.notify("Clangd client not found", vim.log.levels.ERROR)
    end
    local win = vim.api.nvim_get_current_win()
    local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
    ---@diagnostic disable-next-line:param-type-mismatch
    client:request(
        method_name,
        params,
        function(err, res)
            if err or #res == 0 then
                -- Clangd always returns an error, there is no reason to parse it
                return
            end
            local container = string.format("container: %s", res[1].containerName) ---@type string
            local name = string.format("name: %s", res[1].name) ---@type string
            vim.lsp.util.open_floating_preview(
                {name, container},
                "",
                {
                    height = 2,
                    width = math.max(string.len(name), string.len(container)),
                    focusable = false,
                    focus = false,
                    title = "Symbol Info"
                }
            )
        end,
        bufnr
    )
end

---@class ClangdInitializeResult: lsp.InitializeResult
---@field offsetEncoding? string

return {
    cmd = {"clangd"},
    filetypes = {"c", "cpp", "objc", "objcpp", "cuda"},
    root_markers = {
        ".clangd",
        ".clang-tidy",
        ".clang-format",
        "compile_commands.json",
        "compile_flags.txt",
        "configure.ac", -- AutoTools
        ".git"
    },
    capabilities = capabilites,
    ---@param client vim.lsp.Client
    ---@param init_result ClangdInitializeResult
    on_init = function(client, init_result)
        if init_result.offsetEncoding then
            client.offset_encoding = init_result.offsetEncoding
        end
    end,
    ---@param client vim.lsp.Client
    ---@param bufnr integer
    on_attach = function(client, bufnr)
        vim.api.nvim_buf_create_user_command(
            bufnr,
            "LspClangdSwitchSourceHeader",
            function()
                switch_source_header(bufnr, client)
            end,
            {desc = "Switch between source/header"}
        )

        vim.api.nvim_buf_create_user_command(
            bufnr,
            "LspClangdShowSymbolInfo",
            function()
                symbol_info(bufnr, client)
            end,
            {desc = "Show symbol info"}
        )

        -- NOTE: Remember that Lua is a real programming language, and as such it is possible
        -- to define small helper and utility functions so you don't have to repeat yourself.
        --
        -- In this case, we create a function that lets us more easily define mappings specific
        -- for LSP related items. It sets the mode, buffer and description for us each time.
        local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, {buffer = bufnr, desc = "LSP: " .. desc})
        end

        -- Rename the variable under your cursor.
        --  Most Language Servers support renaming across files, etc.
        map("grn", vim.lsp.buf.rename, "[R]e[n]ame")

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", {"n", "x"})

        -- Find references for the word under your cursor.
        map("grr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")

        -- Jump to the implementation of the word under your cursor.
        --  Useful when your language has ways of declaring types without an actual implementation.
        map("gri", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")

        -- Jump to the definition of the word under your cursor.
        --  This is where a variable was first declared, or where a function is defined, etc.
        --  To jump back, press <C-t>.
        map("grd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
        map("gE", vim.diagnostic.open_float, "[G]oto [E]rror diagnostic")
        map("<C-h>", vim.lsp.buf.signature_help, "[G]oto [H]elp", "i")

        -- Fuzzy find all the symbols in your current document.
        --  Symbols are things like variables, functions, types, etc.
        map("gO", require("telescope.builtin").lsp_document_symbols, "Open Document Symbols")

        -- Fuzzy find all the symbols in your current workspace.
        --  Similar to document symbols, except searches over your entire project.
        map("gW", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Open Workspace Symbols")

        -- Jump to the type of the word under your cursor.
        --  Useful when you're not sure what type a variable is and you want to see
        --  the definition of its *type*, not where it was *defined*.
        map("grt", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Definition")

        local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", {clear = false})
        vim.api.nvim_create_autocmd(
            {"CursorHold", "CursorHoldI"},
            {
                buffer = bufnr,
                group = highlight_augroup,
                callback = vim.lsp.buf.document_highlight
            }
        )

        vim.api.nvim_create_autocmd(
            {"CursorMoved", "CursorMovedI"},
            {
                buffer = bufnr,
                group = highlight_augroup,
                callback = vim.lsp.buf.clear_references
            }
        )

        vim.api.nvim_create_autocmd(
            "LspDetach",
            {
                group = vim.api.nvim_create_augroup("kickstart-lsp-detach", {clear = true}),
                callback = function(event2)
                    vim.lsp.buf.clear_references()
                    vim.api.nvim_clear_autocmds {group = "kickstart-lsp-highlight", buffer = event2.buf}
                end
            }
        )
        map(
            "<leader>th",
            function()
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled {bufnr = bufnr})
                print("this was called")
            end,
            "[T]oggle Inlay [H]ints"
        )

        vim.keymap.set("n", "<leader>fm", vim.lsp.buf.format, {desc = "Format buffer"})
        vim.diagnostic.config {
            severity_sort = true,
            float = {border = "rounded", source = "if_many"},
            underline = {severity = vim.diagnostic.severity.ERROR},
            signs = vim.g.have_nerd_font and
                {
                    text = {
                        [vim.diagnostic.severity.ERROR] = "󰅚 ",
                        [vim.diagnostic.severity.WARN] = "󰀪 ",
                        [vim.diagnostic.severity.INFO] = "󰋽 ",
                        [vim.diagnostic.severity.HINT] = "󰌶 "
                    }
                } or
                {},
            virtual_text = {
                source = "if_many",
                spacing = 2,
                format = function(diagnostic)
                    local diagnostic_message = {
                        [vim.diagnostic.severity.ERROR] = diagnostic.message,
                        [vim.diagnostic.severity.WARN] = diagnostic.message,
                        [vim.diagnostic.severity.INFO] = diagnostic.message,
                        [vim.diagnostic.severity.HINT] = diagnostic.message
                    }
                    return diagnostic_message[diagnostic.severity]
                end
            },
            virtual_lines = {current_line = true},
            update_in_insert = true
        }
    end
}
