_: pluginPath:
let
  hooksPath = "${pluginPath}/hooks/hooks.json";
  hasHooks = builtins.pathExists hooksPath;
in
if hasHooks then builtins.fromJSON (builtins.readFile hooksPath) else { }
