{ lib }:
let
  toSettingsJson = import ../../lib/to-settings-json.nix { inherit lib; };
  mkDefaultPermissions = import ../../lib/mk-default-permissions.nix { inherit lib; };

  emptyResult = toSettingsJson { };
  withPerms = toSettingsJson { permissions = mkDefaultPermissions { tool = "claude"; }; };
  withMode = toSettingsJson { defaultMode = "auto"; };
  withPermsAndMode = toSettingsJson {
    permissions = mkDefaultPermissions { tool = "claude"; };
    defaultMode = "auto";
  };
in
{
  # Empty call: only the $schema URL is emitted.

  "test (settings): empty input emits just \\$schema" = {
    expr = builtins.attrNames emptyResult;
    expected = [ "$schema" ];
  };

  "test (settings): \\$schema points at JSON Schema Store entry" = {
    expr = emptyResult."$schema";
    expected = "https://json.schemastore.org/claude-code-settings.json";
  };

  # Null defaults: optional inputs omitted from output (not serialized
  # as JSON nulls).

  "test (settings): null hooks omitted from output" = {
    expr = builtins.hasAttr "hooks" emptyResult;
    expected = false;
  };

  "test (settings): null statusLine omitted from output" = {
    expr = builtins.hasAttr "statusLine" emptyResult;
    expected = false;
  };

  # Permissions: structured input → Claude DSL strings.

  "test (settings): permissions input produces allow/ask/deny lists" = {
    expr = builtins.attrNames withPerms.permissions;
    expected = [
      "allow"
      "ask"
      "deny"
    ];
  };

  "test (settings): shell commands wrapped as Bash(<cmd> *)" = {
    expr = builtins.any (s: s == "Bash(jq *)") withPerms.permissions.allow;
    expected = true;
  };

  "test (settings): WebFetch domains wrapped as WebFetch(domain:<host>)" = {
    expr = builtins.any (s: s == "WebFetch(domain:anthropic.com)") withPerms.permissions.allow;
    expected = true;
  };

  "test (settings): MCP patterns pass through unchanged" = {
    expr = builtins.any (s: s == "mcp__codex__*") withPerms.permissions.allow;
    expected = true;
  };

  "test (settings): deny patterns wrapped as Read(<glob>)" = {
    expr = builtins.any (s: s == "Read(.env)") withPerms.permissions.deny;
    expected = true;
  };

  "test (settings): deny commands wrapped as Bash(<cmd> *)" = {
    expr = builtins.any (s: s == "Bash(sudo rm *)") withPerms.permissions.deny;
    expected = true;
  };

  "test (settings): allow ordering puts WebFetch first, MCP middle, Bash last" = {
    expr =
      let
        idxOf = needle: lib.lists.findFirstIndex (s: s == needle) (-1) withPerms.permissions.allow;
        web = idxOf "WebFetch(domain:anthropic.com)";
        mcp = idxOf "mcp__codex__*";
        bash = idxOf "Bash(jq *)";
      in
      web < mcp && mcp < bash;
    expected = true;
  };

  # extraSettings: caller-supplied overrides merge over the computed
  # output (and the $schema URL).

  "test (settings): extraSettings overrides computed keys" = {
    expr =
      (toSettingsJson {
        extraSettings = {
          model = "claude-opus-4-7";
        };
      }).model;
    expected = "claude-opus-4-7";
  };

  # defaultMode: lands at permissions.defaultMode, works with or without
  # the allow/ask/deny lists.

  "test (settings): defaultMode alone produces permissions.defaultMode" = {
    expr = withMode.permissions.defaultMode;
    expected = "auto";
  };

  "test (settings): defaultMode alone omits allow/ask/deny keys" = {
    expr = builtins.attrNames withMode.permissions;
    expected = [ "defaultMode" ];
  };

  "test (settings): defaultMode with permissions produces all four keys" = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames withPermsAndMode.permissions);
    expected = [
      "allow"
      "ask"
      "defaultMode"
      "deny"
    ];
  };

  "test (settings): null defaultMode omitted from permissions block" = {
    expr = builtins.hasAttr "defaultMode" withPerms.permissions;
    expected = false;
  };
}
