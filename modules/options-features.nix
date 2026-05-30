# Claude Code Module — Feature-flag options
#
# features: opt-in flags including the marketplace plugin schema version
# and an experimental escape hatch for future toggles.
#
# NOTE: `programs.claude.statusline.*` lives in `./statusline/default.nix`.
# The renamed-option-module shim for the upstream `statusLine` (capital L)
# casing also lives there to keep all statusline schema in one place.
{ lib, ... }:
{
  options.programs.claude = {
    features = {
      pluginSchemaVersion = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Marketplace plugin schema version (Claude Code internal).";
      };
      experimental = lib.mkOption {
        type = lib.types.attrsOf lib.types.bool;
        default = { };
        description = "Opt-in experimental flags.";
      };
    };
  };
}
