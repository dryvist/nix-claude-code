{ lib }:
let
  permissions = import ../../lib/permissions.nix { inherit lib; };
  mkDefault = import ../../lib/mk-default-permissions.nix { inherit lib; };
in
{
  # Non-empty: vendored data populated successfully.

  "test: allow.commands is non-empty" = {
    expr = builtins.length permissions.allow.commands > 0;
    expected = true;
  };

  "test: allow.mcp is non-empty" = {
    expr = builtins.length permissions.allow.mcp > 0;
    expected = true;
  };

  "test: ask.commands is non-empty" = {
    expr = builtins.length permissions.ask.commands > 0;
    expected = true;
  };

  "test: deny.commands is non-empty" = {
    expr = builtins.length permissions.deny.commands > 0;
    expected = true;
  };

  "test: deny.patterns is non-empty" = {
    expr = builtins.length permissions.deny.patterns > 0;
    expected = true;
  };

  "test: domains.webfetch is non-empty" = {
    expr = builtins.length permissions.domains.webfetch > 0;
    expected = true;
  };

  # Uniqueness: no duplicates within any list. Uses `lib.unique` which
  # preserves order, so the equality check holds when the list has no
  # repeats regardless of sort order.

  "test: allow.commands has no duplicates" = {
    expr = lib.unique permissions.allow.commands == permissions.allow.commands;
    expected = true;
  };

  "test: allow.mcp has no duplicates" = {
    expr = lib.unique permissions.allow.mcp == permissions.allow.mcp;
    expected = true;
  };

  "test: ask.commands has no duplicates" = {
    expr = lib.unique permissions.ask.commands == permissions.ask.commands;
    expected = true;
  };

  "test: deny.commands has no duplicates" = {
    expr = lib.unique permissions.deny.commands == permissions.deny.commands;
    expected = true;
  };

  "test: deny.patterns has no duplicates" = {
    expr = lib.unique permissions.deny.patterns == permissions.deny.patterns;
    expected = true;
  };

  "test: domains.webfetch has no duplicates" = {
    expr = lib.unique permissions.domains.webfetch == permissions.domains.webfetch;
    expected = true;
  };

  # Safety: a command cannot be both auto-approved and hard-denied. The
  # source-of-truth was reviewed by hand — this gate catches future drift.

  "test: allow.commands and deny.commands are disjoint" = {
    expr = lib.intersectLists permissions.allow.commands permissions.deny.commands;
    expected = [ ];
  };

  # `mkDefaultPermissions` shape contract: callers receive a flat-keyed
  # attrset with the six expected lists for any registered tool.

  "test: mkDefaultPermissions claude returns expected keys" = {
    expr = lib.attrNames (mkDefault {
      tool = "claude";
    });
    expected = [
      "allow"
      "allowMcp"
      "ask"
      "deny"
      "denyPatterns"
      "webfetchDomains"
    ];
  };

  "test: mkDefaultPermissions falls back to base lists for unknown tools" = {
    expr = (mkDefault { tool = "nonexistent-tool"; }).allow == permissions.allow.commands;
    expected = true;
  };

  # Domain whitelist sanity: every entry looks like a bare host (no scheme,
  # no path). Catches `https://example.com` style typos.

  "test: domains.webfetch entries are bare hosts" = {
    expr = builtins.filter (d: lib.hasInfix "/" d || lib.hasInfix ":" d) permissions.domains.webfetch;
    expected = [ ];
  };

  # Pattern shape sanity: every entry contains at least one `*`, `?`, or
  # `~`, or starts with `.`. Catches accidental literal filenames.

  "test: deny.patterns entries look like globs or dotfiles" = {
    expr = builtins.filter (
      p: !(lib.hasInfix "*" p || lib.hasInfix "?" p || lib.hasPrefix "~" p || lib.hasPrefix "." p)
    ) permissions.deny.patterns;
    expected = [ ];
  };
}
