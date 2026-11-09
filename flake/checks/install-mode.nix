# `programs.claude.install` checks for nix-claude-code.
# Each mode must resolve binaryPath, package, and brewCask as docs/settings.md
# states, and an explicit value must still win over the mode's defaults.
{
  inputs,
  self,
  pkgs,
  lib,
  ...
}:
let
  home = {
    username = "ci-tester";
    homeDirectory = "/tmp/ci-tester-home";
    stateVersion = "25.11";
  };

  hmConfig =
    claude:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        self.homeModules.default
        { inherit home; }
        {
          programs.claude = {
            enable = true;
          }
          // claude;
        }
      ];
    };

  evalConfig = claude: (hmConfig claude).config;

  # A failing assertion makes the activation package fail to evaluate.
  # tryEval, not `config.assertions`, because home-manager enforces them
  # during evaluation (same approach as ./config-dir.nix).
  evaluates =
    claude: (builtins.tryEval (builtins.seq (hmConfig claude).activationPackage.drvPath true)).success;

  native = evalConfig { install = "native"; };
  brew = evalConfig { install = "brew"; };
  nix = evalConfig {
    install = "nix";
    package = pkgs.hello;
  };

  cases = {
    native-binary-path = {
      expr = native.programs.claude.binaryPath;
      expected = "${home.homeDirectory}/.local/bin/claude";
    };
    native-package-null = {
      expr = native.programs.claude.package == null;
      expected = true;
    };
    native-brew-cask-null = {
      expr = native.programs.claude.brewCask == null;
      expected = true;
    };
    native-latest-enabled = {
      expr = [
        native.programs.claude.latest.enable
        native.programs.claude.latest.installOnActivation
        native.programs.claude.autoUpdates
      ];
      expected = [
        true
        true
        true
      ];
    };
    native-explicit-package-wins = {
      expr =
        (evalConfig {
          install = "native";
          package = pkgs.hello;
        }).programs.claude.package.outPath;
      expected = pkgs.hello.outPath;
    };

    brew-binary-path = {
      expr = brew.programs.claude.binaryPath;
      expected = "/opt/homebrew/bin/claude";
    };
    brew-cask = {
      expr = brew.programs.claude.brewCask;
      expected = "claude-code@latest";
    };
    brew-package-null = {
      expr = brew.programs.claude.package == null;
      expected = true;
    };
    brew-auto-update-env = {
      expr = brew.programs.claude.settings.env.CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE;
      expected = "1";
    };

    nix-binary-path = {
      expr = nix.programs.claude.binaryPath;
      expected = "${pkgs.hello}/bin/claude";
    };
    nix-package-kept = {
      expr = nix.programs.claude.package.outPath;
      expected = pkgs.hello.outPath;
    };
    nix-brew-cask-null = {
      expr = nix.programs.claude.brewCask == null;
      expected = true;
    };
    nix-latest-untouched = {
      expr = nix.programs.claude.latest.enable;
      expected = false;
    };

    default-install-follows-platform = {
      expr = (evalConfig { package = null; }).programs.claude.install;
      expected = if pkgs.stdenv.hostPlatform.isDarwin then "native" else "nix";
    };

    nix-without-package-rejected = {
      expr = evaluates {
        install = "nix";
        package = null;
      };
      expected = false;
    };
    brew-without-package-accepted = {
      expr = evaluates { install = "brew"; };
      expected = true;
    };
  };

  failures = lib.runTests cases;
in
{
  install-mode =
    if failures == [ ] then
      pkgs.runCommand "install-mode-test" { } ''
        echo "All ${toString (builtins.length (builtins.attrNames cases))} install-mode tests passed." > $out
      ''
    else
      pkgs.runCommand "install-mode-test" { } ''
        cat <<'FAILURES'
        Failed install-mode tests:
        ${builtins.toJSON failures}
        FAILURES
        exit 1
      '';
}
