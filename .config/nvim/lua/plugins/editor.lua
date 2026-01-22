local function get_buf_number()
  return vim.fn.bufnr()
end

local window = function()
    return vim.api.nvim_win_get_number(0)
end

local get_width = function()
  return vim.o.columns / 4 * 3
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
  'projekt0n/github-nvim-theme',
  name = 'github-theme',
  lazy = false, -- make sure we load this during startup if it is your main colorscheme
  priority = 1000, -- make sure to load this before all the other start plugins
  config = function()
    local specs = {
      all = {
        syntax = {
          string = '#98C379',
          module = '#ECBE7B',
          keyword = '#D8B45B',
          trailing = '#E69728',
        },
      }
    }
    local groups = {
      all = {
        String = { fg = 'syntax.string' },
        Keyword = { fg = 'syntax.keyword', style = 'bold' },
        Function = { link = '@variable' },
        ['@module'] = { fg = 'syntax.module', style = 'bold' },
        TrailingWhitespace = { bg = 'syntax.trailing' }
      }
    }
    require('github-theme').setup({
      options = {
        styles = {
        }
      }, specs = specs, groups = groups
    })

    vim.cmd('colorscheme github_dark')
  end,
  },
  { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  {
    'nvim-telescope/telescope.nvim',
     config = function()
        local actions = require("telescope.actions")
        require('telescope').setup(
        {
          defaults = {
            mappings = {
              i = {
                ["<C-Down>"] = actions.cycle_history_next,
                ["<C-Up>"] = actions.cycle_history_prev,
              }
            }
          },
          -- defaults = {mappings = {
          --   ["<C-Down>"] = actions.cycle_history_next,
          --   ["<C-Up>"] = actions.cycle_history_prev,
          -- }},
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
        vim.keymap.set('n', '<leader>fi', function() builtin.find_files {no_ignore=true} end, { desc = 'Telescope find files'})
        vim.keymap.set('n', '<leader>fm', builtin.marks, { desc = 'Telescope find vim marks'})
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Lists available help tags'})
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
      local custom_gruvbox = require'lualine.themes.gruvbox'
      custom_gruvbox.visual.c.bg = custom_gruvbox.normal.c.bg
      custom_gruvbox.visual.c.fg = custom_gruvbox.normal.c.fg
      custom_gruvbox.command.c.bg = custom_gruvbox.normal.c.bg
      custom_gruvbox.command.c.fg = custom_gruvbox.normal.c.fg
      custom_gruvbox.insert.c.bg = custom_gruvbox.normal.c.bg
      custom_gruvbox.insert.c.fg = custom_gruvbox.normal.c.fg

      require('lualine').setup({
        icons_enabled = false,
        -- tabline = {
        --   lualine_a = {{'windows', mode=2}},
        -- },
        sections = {
          lualine_a = {{'mode'}},
          lualine_b = {'branch', {'tabs', mode = 2, max_length=get_width}},
          lualine_c = {},
          lualine_x = {'encoding', 'fileformat', 'filetype'},
          lualine_y = {'progress'},
          lualine_z = {'location', get_buf_number,},
        },
        inactive_sections = {
          lualine_a = {}
        },
        options = {
          theme = require 'lualine.themes.base16',
          component_separators = { left = '|', right = '|'},
          section_separators = { left = '', right = ''},
          globalstatus = true,
        },
        winbar = {
          lualine_b = {window},
          lualine_c = {'diagnostics', {'filename', path=3}, 'diff'},
        },
        inactive_winbar = {
          lualine_b = {window},
          lualine_c = {'filename'},
        },
      })
    end,
  },
  {
    'smoka7/hop.nvim', version = "*", opts = { keys = 'etovxqpdygfblzhckisuran'},
    config = function()
      local hop = require('hop')
      hop.setup { keys = 'etovxqpdygfblzhckisuran' }

      vim.keymap.set('n', '<leader>h', ":HopWordMW<CR>", {remap=true})
      -- local directions = require('hop.hint').HintDirection
          -- vim.keymap.set('', 'f', function()
          --   hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true })
          -- end, {remap=true})
          -- vim.keymap.set('', 'F', function()
          --   hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true })
          -- end, {remap=true})
          -- vim.keymap.set('', 't', function()
          --   hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true, hint_offset = -1 })
          -- end, {remap=true})
          -- vim.keymap.set('', 'T', function()
          --   hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true, hint_offset = 1 })
          -- end, {remap=true})
      vim.keymap.set('n', '<leader>y', "<Cmd>HopYankChar1<CR>", {remap=true})
    end,
  },
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true,
    enabled = false,
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
    opts = {
        custom_key_maps = {
          {"n", "<Leader>|", function() require("multiple-cursors").align() end},
        },
    },  -- This causes the plugin setup function to be called
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
      {"<Leader>cl", "<Cmd>MultipleCursorsLock<CR>", mode = {"n", "x"}, desc = "Lock virtual cursors"},
    },
  },
  {
    "sindrets/winshift.nvim",
    config = function()
      vim.keymap.set('n', '<C-W><C-U>', '<Cmd>WinShift<CR>')
    end
  },
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      file_with_line = {
        create_list_item = function()
          local file_path = vim.fn.expand("%:p") -- Absolute file path
          local line_number = vim.fn.line(".")

          if file_path == "" then
            return nil
          end

          return {
            value = file_path .. ":" .. line_number,
            context = { file_path = file_path, line_number = line_number },
          }
        end,

        select = function(list_item, list, option)
          vim.cmd("edit " .. list_item.context.file_path)

          -- Jump to the line
          vim.api.nvim_win_set_cursor(0, { list_item.context.line_number, 0 })
        end,
      },
    },
    config = function()
      local harpoon = require("harpoon")

      -- REQUIRED
      harpoon:setup()
      -- REQUIRED
      -- vim.keymap.set("n", "<leader>a", function() harpoon:list("file_with_line"):add() end)
      -- vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)
      --

    end
  },
  {
    "michaeljsmith/vim-indent-object",
  },
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {}
  },
  {
    "LintaoAmons/scratch.nvim",
    event = "VeryLazy",
    dependencies = {
      {"ibhagwan/fzf-lua"},
    },
    config = function()
      vim.keymap.set("n", "<leader>sr", "<cmd>Scratch<cr>")
      vim.keymap.set("n", "<leader>sor", "<cmd>ScratchOpen<cr>")
    end
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    opts = {},
    -- enabled = false,
  },
  {
    'stevearc/oil.nvim',
    opts = {
    },
    -- Optional dependencies
    dependencies = { { "nvim-mini/mini.icons", opts = {} } },
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
    config = function()
      require("oil").setup({
        float = {
          max_width = 0.6,
          max_height = 0.6,
        },
        columns = {
          -- "icon",
          -- "permissions",
          -- "size",
          -- "mtime",
        },
      })
      vim.keymap.set("n", "-", "<CMD>Oil --float<CR>", { desc = "Open parent directory" })
    end
  },
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
      "TmuxNavigatorProcessList",
    },
    keys = {
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>", mode="n" },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>", mode="n" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>", mode="n" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>", mode="n" },
      { "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>", mode="n" },
    },
    init = function()
        vim.g.tmux_navigator_no_mappings = 1
    end,
  },
  {
    'stevearc/aerial.nvim',
    keys = {
      { "<leader>oo", "<cmd>AerialToggle float<CR>", desc = "[O]pen [Outline]", mode = "n" },
    },
    opts = {
      filter_kind = false,
      link_tree_to_folds = false,
      show_guides = true,
      backends = { "lsp", "treesitter", "markdown", "asciidoc", "man" },
    },

    dependencies = {
       "nvim-treesitter/nvim-treesitter",
       "nvim-tree/nvim-web-devicons"
    },
  }
}
