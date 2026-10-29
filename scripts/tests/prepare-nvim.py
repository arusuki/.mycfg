"""Install only regression-test dependencies, at lazy-lock.json revisions."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
lock = json.loads((root / ".config/nvim/lazy-lock.json").read_text())
destination = Path(sys.argv[1])
destination.mkdir(parents=True, exist_ok=True)
if any(destination.iterdir()):
    raise SystemExit("Test plugin directory must be empty; use a temporary directory.")

repositories = {
    "scope.nvim": "tiagovla/scope.nvim",
    "nvim-cmp": "hrsh7th/nvim-cmp",
    "LuaSnip": "L3MON4D3/LuaSnip",
    "cmp-nvim-lsp": "hrsh7th/cmp-nvim-lsp",
    "nvim-lspconfig": "neovim/nvim-lspconfig",
    "nvim-dap": "mfussenegger/nvim-dap",
    "nvim-dap-python": "mfussenegger/nvim-dap-python",
    "harpoon": "ThePrimeagen/harpoon",
    "plenary.nvim": "nvim-lua/plenary.nvim",
}
for name, repository in repositories.items():
    path = destination / name
    revision = lock[name]["commit"]
    print(f"Preparing {name} at {revision}", flush=True)
    subprocess.run(["git", "init", "--quiet", str(path)], check=True)
    subprocess.run(["git", "-C", str(path), "fetch", "--quiet", "--depth=1",
                    f"https://github.com/{repository}.git", revision], check=True)
    subprocess.run(["git", "-C", str(path), "checkout", "--quiet", "--detach", "FETCH_HEAD"], check=True)
