return {
  {
    "tpope/vim-fugitive"
  },
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({current_line_blame_opts = {delay = 500}})
      vim.keymap.set('n', '<leader>gh', function()
        require('gitsigns').setqflist(0, { open = false }, vim.schedule_wrap(function(err)
          if err then
            vim.notify(tostring(err), vim.log.levels.ERROR)
            return
          end
          if vim.fn.getqflist({ size = 0 }).size == 0 then
            vim.notify('当前文件没有可显示的 Git hunks', vim.log.levels.INFO)
            return
          end
          require('telescope.builtin').quickfix({ prompt_title = 'Current File Git Hunks' })
        end))
      end, { desc = 'Browse current file Git hunks' })
      vim.keymap.set('n', '<leader>gH', function()
        require('gitsigns').setqflist('all', { open = false }, vim.schedule_wrap(function(err)
          if err then
            vim.notify(tostring(err), vim.log.levels.ERROR)
            return
          end
          if vim.fn.getqflist({ size = 0 }).size == 0 then
            vim.notify('当前工作区没有可显示的 Git hunks', vim.log.levels.INFO)
            return
          end
          require('telescope.builtin').quickfix({ prompt_title = 'Workspace Git Hunks' })
        end))
      end, { desc = 'Browse workspace Git hunks' })
      vim.keymap.set("n", "<leader>gp", ":Gitsigns preview_hunk<CR>", {})
      vim.keymap.set("n", "<leader>gt", ":Gitsigns toggle_current_line_blame<CR>", {})
      vim.keymap.set('n', '<leader>gn', ':Gitsigns next_hunk<CR>')
      vim.keymap.set('n', '<leader>gp', ':Gitsigns prev_hunk<CR>')
      vim.keymap.set('n', '<leader>gw', ':Gitsigns preview_hunk<CR>')
      vim.keymap.set('n', '<leader>giw', ':Gitsigns preview_hunk_inline<CR>')

      vim.keymap.set('n', '<leader>gsh', ':Gitsigns stage_hunk<CR>')
      vim.keymap.set('n', '<leader>gsb', ':Gitsigns stage_buffer<CR>')

      vim.keymap.set('n', '<leader>gus', ':Gitsigns undo_stage_hunk<CR>')
      vim.keymap.set('n', '<leader>grsh', ':Gitsigns reset_hunk<CR>')
      vim.keymap.set('n', '<leader>grsb', ':Gitsigns reset_buffer<CR>')
    end
  }
}
