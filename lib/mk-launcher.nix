{
  pkgs,
  executable,
  nofile,
}:
assert pkgs.lib.assertMsg (builtins.isInt nofile && nofile > 0) "nofile must be a positive integer";
pkgs.writeShellScriptBin "claude" ''
  ulimit -S -n ${toString nofile} || exit 1
  ulimit -H -n ${toString nofile} || exit 1
  exec ${pkgs.lib.escapeShellArg executable} "$@"
''
