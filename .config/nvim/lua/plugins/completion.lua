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
        -- Keep C-b/C-f/C-e owned by config.insert-ops, including with a menu open.
        -- Avoid preset.insert(), which also installs C-e and C-y mappings.
        mapping = {
          ["<C-PageUp>"] = cmp.mapping.scroll_docs(-4),
          ["<C-PageDown>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-y>"] = cmp.mapping.complete(),
          ["<M-e>"] = cmp.mapping.abort(),
          ["<C-n>"] = cmp.mapping(function()
            if cmp.visible() then
              cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
            else
              cmp.complete()
            end
          end),
          ["<C-p>"] = cmp.mapping(function()
            if cmp.visible() then
              cmp.select_prev_item({ behavior = cmp.SelectBehavior.Insert })
            else
              cmp.complete()
            end
          end),
          ["<Down>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
          ["<Up>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
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
        },
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
    "arusuki/suggestions.nvim",
    lazy = false,
    opts = {
      keys = {
        word_left = false, -- Word movement is handled by config.insert-ops.
      },
      input = {
        rules = {
          {
            prompt = "^Compile command:",
            enabled = true,
            completion = "shell",
          },
        },
      },
      highlights = {
        match = { fg = "#ff6E00", bold = true, underline = true },
        selected_match = { fg = "#ff6E00", bold = true, underline = true },
      },
    },
  },
}

