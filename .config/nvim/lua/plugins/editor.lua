local function get_buf_number()
  return vim.fn.bufnr()
end

return {
  {
    "kylechui/nvim-surround",
    version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
        require("nvim-surround").setup({
            -- Configuration here, or leave empty to use defaults
        })
    end
  },
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme "gruvbox"
    end, 
    opts = ...,
  },
  { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  {
    'nvim-telescope/telescope.nvim', tag = '0.1.8',
     config = function()
        require('telescope').setup(
        {
          pickers = {
            find_files = {
              theme = "ivy"
            },
            live_grep = {
              theme = "ivy"
            },
            grep_string = {
              theme = "ivy"
            },
          }
        }
        )
        require('telescope').load_extension('fzf')
        local builtin = require('telescope.builtin')
        local util = require('util')
        local themes = require('telescope.themes')
        util.vars.rg_args = {}
        vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files'})
        vim.keymap.set('n', '<leader>fg', function()
          builtin.live_grep {additional_args=util.get_var("rg_args")}
        end, { desc = 'Telescope live grep'})
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
        vim.keymap.set('n', '<leader>fz', builtin.current_buffer_fuzzy_find, { desc = 'Telescope help tags' })
        vim.keymap.set('v', '<leader>fg', function()
          local selected = util.get_visual_selected_text()
          builtin.grep_string { search=selected, additional_args=util.get_var("rg_args") }
        end,
        { desc = 'Telescope find files in visual mode' }
      )
   end, 
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        icons_enabled = false,
        sections = {
          lualine_z = {'location', get_buf_number},
        },
      })
    end,
  },
  {
    'smoka7/hop.nvim', version = "*", opts = { keys = 'etovxqpdygfblzhckisuran'},
    config = function()
      require'hop'.setup { keys = 'etovxqpdygfblzhckisuran' }
      vim.keymap.set('n', '<leader>h', ":HopWord<CR>", {remap=true})
    end,
  },
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true
    -- use opts = {} for passing setup options
    -- this is equivalent to setup({}) function
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
      "mrbjarksen/neo-tree-diagnostics.nvim",
      -- {"3rd/image.nvim", opts = {}}, -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    lazy = false, -- neo-tree will lazily load itself
    ---@module "neo-tree"
    ---@type neotree.Config?
    opts = {
      -- fill any relevant options here
    },
    config = function()
      vim.keymap.set("n", "<leader>e", ":Neotree filesystem toggle left<CR>", {})
      vim.keymap.set("n", "<leader>ob", ":Neotree buffers reveal float<CR>", {})
      vim.keymap.set("n", "<leader>oe", ":Neotree diagnostics reveal float<CR>", {})
      vim.keymap.set("n", "<leader>og", ":Neotree git_status reveal float<CR>", {})
      require("neo-tree").setup({
          sources = {
            "filesystem",
            "buffers",
            "git_status",
            "diagnostics",
          },
      })
    end,
  },
  {
    "brenton-leighton/multiple-cursors.nvim",
    version = "*",  -- Use the latest tagged version
    opts = {},  -- This causes the plugin setup function to be called
    keys = {
      {"<C-Up>", "<Cmd>MultipleCursorsAddUp<CR>", mode = {"n", "i", "x"}, desc = "Add cursor and move up"},
      {"<C-Down>", "<Cmd>MultipleCursorsAddDown<CR>", mode = {"n", "i", "x"}, desc = "Add cursor and move down"},

      -- {"<C-LeftMouse>", "<Cmd>MultipleCursorsMouseAddDelete<CR>", mode = {"n", "i"}, desc = "Add or remove cursor"},
      -- {"<Leader>m", "<Cmd>MultipleCursorsAddVisualArea<CR>", mode = {"x"}, desc = "Add cursors to the lines of the visual area"},
      -- {"<Leader>a", "<Cmd>MultipleCursorsAddMatches<CR>", mode = {"n", "x"}, desc = "Add cursors to cword"},
      -- {"<Leader>A", "<Cmd>MultipleCursorsAddMatchesV<CR>", mode = {"n", "x"}, desc = "Add cursors to cword in previous area"},

      {"<Leader>d", "<Cmd>MultipleCursorsAddJumpNextMatch<CR>", mode = {"n", "x"}, desc = "Add cursor and jump to next cword"},
      {"<Leader>u", "<Cmd>MultipleCursorsJumpPrevMatch<CR>", mode = {"n", "x"}, desc = "Remove cursor to previous cword"},
      {"<Leader>D", "<Cmd>MultipleCursorsJumpNextMatch<CR>", mode = {"n", "x"}, desc = "Jump to next cword"},
      {"<Leader>l", "<Cmd>MultipleCursorsLock<CR>", mode = {"n", "x"}, desc = "Lock virtual cursors"},
    },
  },
  {
    "sindrets/winshift.nvim",
    config = function()
      vim.keymap.set('n', '<C-W><C-U>', '<Cmd>WinShift<CR>')
    end
  },
}
