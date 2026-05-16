_: pluginPath:
let
  manifestPath = "${pluginPath}/.claude-plugin/plugin.json";
  hasManifest = builtins.pathExists manifestPath;
  manifest = if hasManifest then builtins.fromJSON (builtins.readFile manifestPath) else { };
in
{
  name = manifest.name or "unknown";
  description = manifest.description or "";
  version = manifest.version or null;
  author = manifest.author or { };
  raw = manifest;
}
