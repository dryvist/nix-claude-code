# Install method for the Claude Code binary: Anthropic's native installer,
# Homebrew, or the nix package. Each mode drives the existing options with
# lib.mkDefault, so setting any of those options explicitly still wins.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude;

  # The one definition of each install location and cask name. The native
  # installer (https://claude.ai/install.sh) places the binary at the native
  # path; Homebrew links the cask at the brew path.
  nativeBinaryPath = "${config.home.homeDirectory}/.local/bin/claude";
  brewBinaryPath = "/opt/homebrew/bin/claude";
  brewCaskName = "claude-code@latest";

  isNative = cfg.install == "native";
  isBrew = cfg.install == "brew";
in
{
  options.programs.claude = {
    install = lib.mkOption {
      type = lib.types.enum [
        "native"
        "brew"
        "nix"
      ];
      default = if pkgs.stdenv.hostPlatform.isDarwin then "native" else "nix";
      defaultText = lib.literalExpression ''if pkgs.stdenv.isDarwin then "native" else "nix"'';
      description = ''
        How the Claude Code binary is installed.
        - "native": Anthropic's installer, run at home-manager activation and
          self-updated by Claude Code. Sets `package = null`, enables
          `latest`, and turns on `autoUpdates`. Darwin only.
        - "brew": the Homebrew cask (`brewCask`). Sets `package = null` and
          `CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE = "1"` in `settings.env`.
        - "nix": the `package` option, unchanged.
      '';
    };

    binaryPath = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        Absolute path of the Claude Code binary for the selected `install`
        mode. Derived from `install`; not settable.
      '';
    };

    brewCask = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      description = ''
        Homebrew cask that provides Claude Code when `install = "brew"`,
        otherwise `null`. Derived from `install`; not settable.
      '';
    };
  };

  config = lib.mkMerge [
    {
      programs.claude = {
        binaryPath =
          if isNative then
            nativeBinaryPath
          else if isBrew then
            brewBinaryPath
          else
            lib.throwIf (cfg.package == null)
              "programs.claude.install = \"nix\" requires programs.claude.package to be set."
              "${cfg.package}/bin/claude";
        brewCask = if isBrew then brewCaskName else null;
      };
    }

    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.install != "nix" || cfg.package != null;
          message = "programs.claude.install = \"nix\" requires programs.claude.package to be set.";
        }
      ];
    })

    (lib.mkIf (cfg.enable && isNative) {
      programs.claude = {
        package = lib.mkOverride 900 null; # beats a consumer mkDefault package
        latest = {
          enable = lib.mkDefault true;
          installOnActivation = lib.mkDefault true;
        };
        autoUpdates = lib.mkDefault true;
      };
    })

    (lib.mkIf (cfg.enable && isBrew) {
      programs.claude = {
        package = lib.mkOverride 900 null; # beats a consumer mkDefault package
        settings.env.CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE = lib.mkDefault "1";
      };
    })
  ];
}
