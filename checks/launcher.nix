{ pkgs, mkLauncher }:
let
  fixtures = [
    64
    128
  ];
  child = pkgs.writeShellScript "launcher-child" ''
    printf 'soft=%s hard=%s\n' "$(ulimit -S -n)" "$(ulimit -H -n)"
    printf '<%s>\n' "$@"
  '';
  launcher =
    nofile:
    mkLauncher {
      inherit pkgs nofile;
      executable = child;
    };
  external = mkLauncher {
    inherit pkgs;
    nofile = builtins.head fixtures;
    executable = "/launcher-fixture/bin/external-cli";
  };
  invalid = [
    0
    (-1)
    "64"
    1.5
    null
  ];
in
assert (builtins.functionArgs mkLauncher).nofile == false;
assert builtins.all (nofile: !(builtins.tryEval (launcher nofile).drvPath).success) invalid;
pkgs.runCommand "claude-launcher-check" { } ''
  mkdir -p "$out"
  test -x ${external}/bin/claude
  cp ${external}/bin/claude "$out/external-wrapper"
  ${pkgs.lib.concatMapStringsSep "\n" (
    nofile:
    let
      wrapper = "${launcher nofile}/bin/claude";
      value = toString nofile;
    in
    ''
      grep -F 'ulimit -S -n ${value} || exit 1' ${wrapper}
      grep -F 'ulimit -H -n ${value} || exit 1' ${wrapper}
      cp ${wrapper} "$out/wrapper-${value}"
      ${wrapper} 'two words' "" '*' > "$out/actual-${value}"
      printf 'soft=${value} hard=${value}\n<two words>\n<>\n<*>\n' > "$out/expected-${value}"
      diff -u "$out/expected-${value}" "$out/actual-${value}"
      if (ulimit -S -n 32; ulimit -H -n 32; exec ${wrapper}) > "$out/rejected-${value}" 2> "$out/rejected-${value}.stderr"; then
        echo "launcher accepted an unavailable limit" >&2
        exit 1
      fi
      test ! -s "$out/rejected-${value}"
      test -s "$out/rejected-${value}.stderr"
    ''
  ) fixtures}
  echo "rendered limits, inherited limits, arguments, rejection, and input validation passed" > "$out/result"
''
