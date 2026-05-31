_: {
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        inputsFrom = [ config.treefmt.build.devShell ];
        # Warn before pre-commit's installer fires: a set core.hooksPath
        # makes it refuse with "Cowardly refusing to install hooks with
        # core.hooksPath set". The fix is to unset, not to bypass.
        shellHook = ''
          if [ -n "$(git config --get core.hooksPath 2>/dev/null)" ]; then
            echo "WARN: core.hooksPath is set to '$(git config --get core.hooksPath)'." >&2
            echo "      pre-commit install will refuse. Unset it:" >&2
            echo "        git config --unset core.hooksPath           # local" >&2
            echo "        git config --global --unset core.hooksPath  # global" >&2
          fi
          ${config.pre-commit.installationScript}
        '';
        packages = with pkgs; [
          nixfmt-rfc-style
          nil
          nix-tree
          nix-output-monitor
        ];
      };
    };
}
