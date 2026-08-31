# A marketplace entry must resolve INSIDE its marketplace root.
#
# Claude Code >= 2.1.251 refuses to install a plugin whose source path leaves
# the marketplace directory ("its marketplace entry path does not stay inside
# the marketplace directory ... link-traversing entry"). A wrapper that builds
# its output as `ln -s ${src}/...` puts every entry in the INPUT's store path
# rather than the wrapper's own, so the marketplace still validates while every
# plugin in it silently fails to install.
#
# The key MUST start with "test": lib.runTests silently ignores any attribute
# that does not, so a mis-named case is a guard that never runs and always
# reports green.
#
# This is a source-level guard rather than a build-and-inspect one on purpose:
# the failure is a property of how the wrapper is WRITTEN, one grep catches the
# whole class, and it costs no build. When jacobpevans-cc-plugins was fixed by
# hand the browser-use and cribl wrappers kept the same bug precisely because
# nothing checked for it.
{ lib }:
let
  overrides = builtins.readFile ../../modules/marketplace-overrides.nix;
in
{
  "test: marketplace wrappers copy entries instead of symlinking out of $out" = {
    expr = lib.hasInfix "ln -s" overrides;
    expected = false;
  };
}
