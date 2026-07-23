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
    "arusuki/wilder.nvim",
    init = function(plugin)
      vim.opt.rtp:append(plugin.dir .. "/wilder-fzf")
    end,

    config = function()
        local wilder_fzf = require('wilder_fzf')
        wilder_fzf.setup({
          -- reverse = 1,
          highlights = {
            accent = wilder_fzf.make_hl('WilderFzfPink', 'Pmenu', {
              foreground = '#ff6E00',
              bold = true,
              underline = true,
            }),
            selected_accent = wilder_fzf.make_hl('WilderFzfSelectedPink', 'PmenuSel', {
              foreground = '#ff6E00',
              bold = true,
              underline = true,
            }),
          },
        })
    end,
    lazy = false,
  },
}

