return {
  'echasnovski/mini.files',
  version = false,
  keys = {
    {
      '<leader>e',
      function()
        local MiniFiles = require('mini.files')
        -- Open at current file's directory, or cwd if no file
        local file = vim.api.nvim_buf_get_name(0)
        local file_exists = vim.fn.filereadable(file) == 1
        MiniFiles.open(file_exists and file or nil)
        if file_exists then
          MiniFiles.reveal_cwd()
        end
      end,
      desc = 'File [E]xplorer (current file)',
    },
    {
      '<leader>E',
      function()
        require('mini.files').open(vim.uv.cwd(), true)
      end,
      desc = 'File [E]xplorer (cwd)',
    },
  },
  opts = {
    -- Customize navigation mappings
    mappings = {
      close = 'q',
      go_in = 'l',
      go_in_plus = '<CR>',
      go_out = 'h',
      go_out_plus = 'H',
      mark_goto = "'",
      mark_set = 'm',
      reset = '<BS>',
      reveal_cwd = '@',
      show_help = 'g?',
      synchronize = '=',
      trim_left = '<',
      trim_right = '>',
    },

    -- Show preview window
    windows = {
      preview = true,
      width_focus = 30,
      width_nofocus = 15,
      width_preview = 50,
    },

    options = {
      -- Use as default explorer instead of netrw
      use_as_default_explorer = true,
      -- Don't permanently delete, move to trash
      permanent_delete = false,
    },

    -- Confirm before destructive actions
    confirm = {
      fs_actions = true,
    },
  },
}
