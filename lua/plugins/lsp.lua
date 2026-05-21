return {
  -- LSP Plugins
  {
    -- KCL language support (syntax highlighting, folding, etc.)
    'kcl-lang/kcl.nvim',
    ft = 'kcl',
  },
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      -- Helper to find executable, preferring system paths on NixOS over Mason
      local function resolve_lsp_cmd(name, args)
        local nixos_path = '/run/current-system/sw/bin/' .. name
        if vim.fn.executable(nixos_path) == 1 then
          local cmd = { nixos_path }
          if args then
            for _, arg in ipairs(args) do
              table.insert(cmd, arg)
            end
          end
          return cmd
        end
        return nil -- fall back to default (PATH lookup)
      end

      -- Detect NixOS
      local is_nixos = vim.fn.executable('/run/current-system/sw/bin/nixos-version') == 1

      -- Servers to skip Mason installation (installed via system/NixOS)
      local skip_mason = { 'rust_analyzer' }
      if is_nixos then
        vim.list_extend(skip_mason, { 'clangd', 'lua_ls' })
      end

      -- =============================================
      -- GLOBAL LSP CONFIG (applies to all servers)
      -- =============================================
      vim.lsp.config('*', {
        capabilities = require('blink.cmp').get_lsp_capabilities(),
        root_markers = { '.git' },
      })

      -- =============================================
      -- SERVER-SPECIFIC CONFIGS (vim.lsp.config)
      -- =============================================

      -- Lua
      local lua_ls_cmd = resolve_lsp_cmd('lua-language-server')
      vim.lsp.config('lua_ls', {
        cmd = lua_ls_cmd,
        settings = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
            -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
            -- diagnostics = { disable = { 'missing-fields' } },
          },
        },
      })

      -- Clangd
      local clangd_cmd = resolve_lsp_cmd('clangd', { '--background-index', '--clang-tidy' })
      vim.lsp.config('clangd', {
        cmd = clangd_cmd,
      })

      -- TypeScript/JavaScript
      vim.lsp.config('ts_ls', {
        filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
      })

      -- Tailwind CSS
      vim.lsp.config('tailwindcss', {
        filetypes = { 'html', 'css', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
      })

      -- OpenTofu
      vim.lsp.config('tofu_ls', {
        filetypes = { 'opentofu', 'opentofu-vars', 'terraform', 'tfvars' },
        root_markers = { '.terraform', '.git' },
        single_file_support = true,
      })

      -- Go, HTML, Terraform, Pyright, Rust - use defaults
      -- (nvim-lspconfig provides sensible defaults via lsp/*.lua files)

      -- =============================================
      -- ENABLE SYSTEM-INSTALLED SERVERS
      -- =============================================
      -- These are not managed by Mason (installed via NixOS or system)
      vim.lsp.enable(skip_mason)

      -- =============================================
      -- MASON SETUP
      -- =============================================

      -- Tools to install via Mason
      local mason_ensure_installed = { 'stylua', 'prettier' }

      -- Servers to install via Mason (excluding system-installed ones)
      local mason_servers = { 'gopls', 'ts_ls', 'tailwindcss', 'html', 'tofu_ls', 'pyright', 'kcl' }
      vim.list_extend(mason_ensure_installed, mason_servers)

      require('mason-tool-installer').setup { ensure_installed = mason_ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = mason_servers,
        automatic_enable = {
          exclude = skip_mason, -- Don't auto-enable system-installed servers (already enabled above)
        },
      }

      -- =============================================
      -- LSP ATTACH AUTOCMD
      -- =============================================
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- Helper to define LSP keymaps
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- Find references for the word under your cursor (using Telescope).
          map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor (using Telescope).
          map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the definition of the word under your cursor (using Telescope).
          map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- Fuzzy find all the symbols in your current document (using Telescope).
          map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')

          -- Fuzzy find all the symbols in your current workspace (using Telescope).
          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')

          -- Jump to the type of the word under your cursor (using Telescope).
          map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

          map('ghd', vim.lsp.buf.hover, 'Hover Documentation')

          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            return client:supports_method(method, bufnr)
          end

          -- Highlight references of the word under cursor when cursor rests there
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- Toggle inlay hints keymap
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- =============================================
      -- DIAGNOSTIC CONFIG
      -- =============================================
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true, sql = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        html = { 'prettier' },
        javascript = { 'prettier' },
        typescript = { 'prettier' },
        css = { 'prettier' },
        scss = { 'prettier' },
        sql = {},
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {},
        opts = {},
      },
      'folke/lazydev.nvim',
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        preset = 'none',

        ['<C-l>'] = { 'select_and_accept', 'fallback' },
        ['<C-k>'] = { 'select_prev', 'fallback' },
        ['<C-j>'] = { 'select_next', 'fallback' },
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- By default, we use the Lua implementation instead, but you may enable
      -- the rust implementation via `'prefer_rust_with_warning'`
      --
      -- See :h blink-cmp-config-fuzzy for more information
      fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },
}
