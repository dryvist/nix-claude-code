{ pkgs }:
{
  marketplaceName,
}:
# Synthesizes SKILL.md derivations from commands/<name>.md so tools that only
# consume skills (e.g. agent-skills in nix-ai) can present command-style plugins
# as skills. Returns a derivation containing the synthesized tree.
pkgs.runCommand "wrap-commands-as-skills-${marketplaceName}" { } ''
  mkdir -p "$out/skills"
  echo "stub — real wrapping logic lands in Checkpoint 1" > "$out/STUB"
''
