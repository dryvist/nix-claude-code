{ ... }:
{
  imports = [
    # Core: enable, package, permissions, defaultMode, autoMode (settings is
    # declared in options-settings.nix as a freeform submodule).
    ./core.nix

    # Option declarations (split for readability).
    ./options-runtime.nix
    ./options-content.nix
    ./options-events.nix
    ./options-features.nix
    ./options-settings.nix

    # Config-only modules.
    ./plugins.nix
    ./hooks.nix
    ./mcp.nix
    ./latest.nix
    ./components.nix
    ./registry.nix
    ./orphan-cleanup.nix
    ./settings.nix
    ./api-key-helper.nix
    ./statusline

    # NOTE: `./marketplace-overrides.nix` and `./plugins-catalog/` are
    # libraries (functions / data), not modules. Consumers import them
    # explicitly via `flake.lib.marketplaceOverrides` and
    # `flake.lib.marketplaceCatalog`.
  ];
}
