_: cfg:
# Takes a programs.claude.* config attrset and returns the contents of
# ~/.claude/settings.json as a Nix attrset. Final shape follows
# https://json.schemastore.org/claude-code-settings.json.
{
  "$schema" = "https://json.schemastore.org/claude-code-settings.json";
}
// cfg.settings or { }
