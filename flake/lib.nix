{ inputs, ... }:
let
  lib = inputs.nixpkgs.lib;
  ncc = import ../lib { inherit lib; };

  marketplaceCatalog = import ../modules/plugins-catalog/marketplaces.nix { inherit lib; };

  # CI shim used to byte-equivalent-test settings.json output. Keeping it
  # in `flake.lib.ci.*` lets downstream repos do exact comparisons during
  # PR review without instantiating a full home-manager activation.
  ciClaudeSettingsJson =
    let
      # Empty by design, matching what the home-manager modules deploy: no
      # hard-coded allow/ask/deny rules for Claude Code, with the auto-mode
      # classifier as the only gate. `defaultMode` keeps the `permissions`
      # block itself present in the render.
      permissions = {
        allow = [ ];
        ask = [ ];
        deny = [ ];
      };
    in
    builtins.toJSON (
      ncc.toSettingsJson {
        inherit permissions;
        defaultMode = "auto";
        # Match nix-ai's pre-port byte-equivalent output by passing the
        # additionalDirectories the CI fixture historically embedded under
        # both top-level `additionalDirectories` and
        # `permissions.additionalDirectories`.
        #
        # The "~/.claude/" below is a frozen literal ON PURPOSE and must NOT
        # follow programs.claude.configDir, even though modules/settings.nix
        # now renders "~/${cfg.configDir}/". This shim reproduces a fixed
        # historical byte sequence for the parity comparison; deriving it
        # from configDir would make the snapshot move with configuration and
        # defeat the point of comparing against it.
        extraSettings = {
          additionalDirectories = [ "~/.claude/" ];
          alwaysThinkingEnabled = true;
          permissions.additionalDirectories = [ "~/.claude/" ];
          extraKnownMarketplaces = lib.mapAttrs ncc.claudeRegistry.toClaudeMarketplaceFormat marketplaceCatalog.marketplaces;
        };
      }
    );
in
{
  flake.lib = ncc // {
    inherit marketplaceCatalog;

    # `marketplaceOverrides { inherit pkgs; ... }` returns synthetic
    # marketplace derivations (browserUseMarketplace, fabricMarketplace,
    # criblPackValidatorMarketplace, jacobpevansMarketplace). Pass the
    # `marketplaceInputs`, `fabric-src`, `fabricVersion`, `browserUseVersion`
    # the caller wants to materialize.
    marketplaceOverrides = import ../modules/marketplace-overrides.nix;

    ci = {
      claudeSettingsJson = ciClaudeSettingsJson;
    };
  };
}
