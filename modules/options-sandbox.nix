# The `settings.sandbox` submodule body, extracted so `options-settings.nix`
# stays under the per-file size limit.
#
# Only `enabled`, `autoAllowBashIfSandboxed` and `excludedCommands` used to be
# typed here, and `./settings.nix` rendered exactly those three by name. Because
# `sandbox` is in that file's `knownSettingsKeys`, the whole attrset is removed
# from the freeform passthrough — so any other sub-key a caller set was dropped
# on the floor rather than reaching settings.json. The keys that decide whether
# the sandbox contains anything (`network`, `filesystem`, `failIfUnavailable`)
# were exactly the ones being dropped. They are typed below and the renderer now
# emits every non-null sub-key.
# See: https://code.claude.com/docs/en/settings
{ lib, ... }:
{
  freeformType = lib.types.attrs;
  options = {
    enabled = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sandbox mode for filesystem/network isolation.";
    };

    autoAllowBashIfSandboxed = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically allow bash commands when sandboxed.";
    };

    excludedCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Commands to exclude from sandbox restrictions";
      example = [
        "git"
        "nix"
        "darwin-rebuild"
      ];
    };

    # --- What the sandbox actually contains -----------------------------
    # Left as `attrs` rather than a modelled schema: upstream shapes these as
    # open objects and a stricter type here would reject a valid policy the
    # moment upstream adds a field. They are typed as *present* so a caller's
    # value reaches settings.json and is documented, which is the defect this
    # file fixes.

    network = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = ''
        Network policy for sandboxed commands — which destinations are
        reachable. null = upstream default.
      '';
    };

    filesystem = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = ''
        Filesystem policy for sandboxed commands — which paths are readable
        and writable. null = upstream default.
      '';
    };

    failIfUnavailable = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Refuse to run when sandboxing is unavailable on the platform, rather
        than continuing unsandboxed. Fail-closed. null = upstream default.
      '';
    };

    allowUnsandboxedCommands = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Permit commands to run outside the sandbox when they cannot be
        sandboxed. null = upstream default.
      '';
    };

    ignoreViolations = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Continue after a sandbox violation instead of treating it as an error.
        null = upstream default.
      '';
    };

    enabledPlatforms = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Platforms on which sandboxing applies. null = upstream default.
      '';
      example = [ "darwin" ];
    };

    allowAppleEvents = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Allow Apple Events from sandboxed commands on macOS.
        null = upstream default.
      '';
    };
  };
}
