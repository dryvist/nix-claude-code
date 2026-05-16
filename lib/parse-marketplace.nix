_: marketplacePath:
let
  manifestPath = "${marketplacePath}/.claude-plugin/marketplace.json";
  hasManifest = builtins.pathExists manifestPath;
  manifest = if hasManifest then builtins.fromJSON (builtins.readFile manifestPath) else { };
in
{
  name = manifest.name or "unknown";
  description = manifest.description or "";
  owner = manifest.owner or { };
  plugins = manifest.plugins or [ ];
  raw = manifest;
}
