_:
# A minimal home-manager configuration consuming nix-claude-code.
# See templates/minimal/ for a full working flake.
{
  programs.claude = {
    enable = true;
    statusline.enable = true;
  };
}
