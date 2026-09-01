{
  config,
  lib,
  pkgs,
  claude-swap,
  ...
}:
let
  cfg = config.programs.claude.swap;
  package = import ../packages/claude-swap.nix {
    inherit pkgs;
    src = claude-swap;
  };
in
{
  options.programs.claude.swap.disabled = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether the claude-swap account-switching CLI is disabled. When false,
      installs `cswap` and `claude-swap`; account credentials remain managed by
      Claude Code and the platform credential store.
    '';
  };

  config = lib.mkIf (!cfg.disabled) {
    home.packages = [ package ];
  };
}
