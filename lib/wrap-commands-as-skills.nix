{ lib, pkgs }:
{
  commands,
  outputDir ? "skills",
  name ? "synthesized-skills",
  fallbackDescription ? null,
}:
# Synthesize SKILL.md derivations from `commands/<name>.md` so tools that
# only consume skills (the agent-skills module in nix-ai, codex, gemini)
# can ingest command-style plugin entries uniformly.
#
# Inputs:
#   - `commands`           : list of `{ name; path; pluginRoot; }` from
#                            `lib.discoverCommands`
#   - `outputDir`          : subdirectory under the derivation `$out` where
#                            the `<name>/SKILL.md` tree is written
#                            (default `"skills"`)
#   - `name`               : derivation name; useful for marketplace
#                            attribution when wrapping many at once
#   - `fallbackDescription`: optional override for the description line in
#                            the synthesized frontmatter (defaults to a
#                            generic message that references the source
#                            command path)
let
  defaultDescription = cmdName: "Synthesized from commands/${cmdName}.md";

  describe =
    cmdName: if fallbackDescription == null then defaultDescription cmdName else fallbackDescription;

  # Build a frontmatter prelude for each command. Using `writeText` keeps
  # the body interpolation out of the shell script so command names with
  # punctuation don't break the build.
  frontmatterFor =
    cmd:
    pkgs.writeText "skill-frontmatter-${cmd.name}" ''
      ---
      name: ${cmd.name}
      description: ${describe cmd.name}
      ---

    '';

  emitOne =
    cmd:
    let
      fm = frontmatterFor cmd;
    in
    ''
      mkdir -p "$out/${outputDir}/${cmd.name}"
      cat ${fm} ${cmd.path} > "$out/${outputDir}/${cmd.name}/SKILL.md"
    '';
in
pkgs.runCommand name { } (
  "mkdir -p \"$out/${outputDir}\"\n" + lib.concatMapStringsSep "\n" emitOne commands
)
