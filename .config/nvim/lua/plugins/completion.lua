return {
  {
    "L3MON4D3/LuaSnip",
    dependencies = {
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()
      vim.keymap.set('i', '<C-y>', function() cmp.complete() end)
      cmp.setup({
        completion = {autocomplete=false},
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" }, -- For luasnip users.
        }, {
          { name = "path" },
          { name = "buffer" },
        }),
      })
    end,
  },
  {
    "gelguy/wilder.nvim",
    event = "CmdlineEnter",
    build = ":UpdateRemotePlugins",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local wilder = require "wilder"
      wilder.setup {
        modes = { ":", "/", "?" },
        next_key = '<Tab>',
        previous_key = '<S-Tab>',
        accept_key = '<C-N>',
        reject_key = '<C-P>',
      }
      wilder.set_option("pipeline", {
        wilder.branch(
          wilder.python_file_finder_pipeline {
            file_command = function(_, arg)
              if string.find(arg, ".") ~= nil then
                return { "fd", "-tf", "-H" }
              else
                return { "fd", "-tf" }
              end
            end,
            dir_command = { "fd", "-td" },
            filters = { "fuzzy_filter", "difflib_sorter" },
          },
          wilder.cmdline_pipeline({
            language = 'python',
            fuzzy = 1,
          }),
          wilder.python_search_pipeline({pattern="fuzzy"})
        ),
      })

      theme = wilder.popupmenu_border_theme({
        highlighter = wilder.basic_highlighter(),
        highlights = {
          default = "WilderMenu",
          accent = wilder.make_hl("WilderAccent", "Pmenu", {
            { a = 1 },
            { a = 1 },
            { foreground = "#ff6E00" },
          }),
        },
        min_width = '100%',
        border = 'single',
      })

      theme.left = {"│ ", wilder.popupmenu_devicons() }
      wilder.set_option("renderer", wilder.popupmenu_renderer(theme))
    end,
  },
}

