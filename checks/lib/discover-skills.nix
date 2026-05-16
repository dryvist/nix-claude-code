{ lib }:
let
  discoverSkills = import ../../lib/discover-skills.nix { inherit lib; };
in
{
  "test: returns empty list for empty path" = {
    expr = discoverSkills ./fixtures/empty;
    expected = [ ];
  };
}
