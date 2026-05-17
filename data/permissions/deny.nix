_:
# Hard-denied actions and file-path patterns.
#
# Vendored from ai-assistant-instructions/agentsmd/permissions/deny/*.json
# (snapshot: 2026-05-16). Categories: dangerous (catastrophic system
# operations), git (hook-bypassing operations), network (mutating HTTP
# verbs), package-install (package-manager installs that need explicit
# user confirmation each time), shell (inline interpreter invocations).
{
  commands = [
    # dangerous (catastrophic destruction)
    "diskutil"
    "fdisk"
    "mkfs"
    "rm --recursive --force /"
    "rm --recursive --force ~"
    "rm -fr /"
    "rm -fr ~"
    "rm -rf /"
    "rm -rf ~"
    "sudo -i"
    "sudo -s"
    "sudo bash"
    "sudo dd"
    "sudo rm"
    "sudo su"

    # git (hook-bypass and history-corruption)
    "chmod -x .git/hooks/"
    "git -c core.hooksPath"
    "git cherry-pick --no-verify"
    "git commit --no-verify"
    "git commit -n"
    "git config core.hooksPath"
    "git merge --no-verify"
    "git rebase --no-verify"
    "pre-commit uninstall"
    "rm -rf .git/hooks"
    "rm -rf .git/hooks/"
    "rm .git/hooks"
    "rm .git/hooks/"

    # network (mutating HTTP verbs and inbound listeners)
    "curl --data"
    "curl --request DELETE"
    "curl --request PATCH"
    "curl --request POST"
    "curl --request PUT"
    "curl -X DELETE"
    "curl -X PATCH"
    "curl -X POST"
    "curl -X PUT"
    "curl -d"
    "nc -l"
    "ncat -l"
    "socat"

    # package-install (force confirmation for installs)
    "bundle install"
    "cargo install"
    "composer install"
    "composer require"
    "conda install"
    "gem install"
    "go install"
    "mamba install"
    "micromamba install"
    "npm ci"
    "npm i"
    "npm install"
    "npm run"
    "npm test"
    "pip install"
    "pip3 install"
    "pnpm add"
    "pnpm install"
    "poetry add"
    "poetry install"
    "python -m pip install"
    "python3 -m pip install"
    "yarn add"
    "yarn install"

    # shell (inline interpreter execution and temp-file writes)
    "bash -c"
    "cat > /tmp/"
    "cat >> /tmp/"
    "dash -c"
    "fish -c"
    "ksh -c"
    "node --eval"
    "node -e"
    "perl -c"
    "perl -e"
    "python -"
    "python -c"
    "python /dev/"
    "python /tmp/"
    "python <<"
    "python3 -"
    "python3 -c"
    "python3 /dev/"
    "python3 /tmp/"
    "python3 <<"
    "ruby --eval"
    "ruby -e"
    "sh -c"
    "tee /tmp/"
    "zsh -c"
  ];

  # File-path glob patterns to deny across all `Read`/`Edit`/`Write` calls.
  # Contributed only by `deny/dangerous.json` in the source split.
  patterns = [
    "**/*_dsa"
    "**/*_ecdsa"
    "**/*_ed25519"
    "**/*_rsa"
    "**/.env"
    "**/.env.*"
    "**/credentials/**"
    "**/secrets/**"
    ".env"
    ".env.*"
    "~/.aws/credentials"
    "~/.gnupg/**"
    "~/.ssh/id_*"
  ];
}
