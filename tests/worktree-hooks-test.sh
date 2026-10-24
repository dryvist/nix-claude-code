#!/usr/bin/env bash
# Regression test for modules/hooks/worktree-create.sh and worktree-remove.sh.
#
# Run as a Nix check (see flake/checks.nix), which supplies:
#   CREATE  store path of the create hook
#   REMOVE  store path of the remove hook
#   out     file to write the success marker to

set -euo pipefail

export HOME=$TMPDIR
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

origin=$TMPDIR/origin.git
empty_origin=$TMPDIR/empty-origin.git
seed=$TMPDIR/seed
repo=$TMPDIR/repo
git init -q --bare "$origin"
git init -q -b main "$seed"
git -C "$seed" commit -q --allow-empty -m init
git -C "$seed" remote add origin "$origin"
git -C "$seed" push -q origin main
git --git-dir="$origin" symbolic-ref HEAD refs/heads/main
git clone -q "$origin" "$repo"

# Move the remote default after cloning so origin/HEAD is stale locally.
git -C "$seed" switch -q -c fresh-default
git -C "$seed" commit -q --allow-empty -m fresh-default
git -C "$seed" push -q origin fresh-default
git --git-dir="$origin" symbolic-ref HEAD refs/heads/fresh-default
[ "$(git -C "$repo" symbolic-ref refs/remotes/origin/HEAD)" = refs/remotes/origin/main ] || {
  echo "expected origin/HEAD to be stale before WorktreeCreate" >&2
  exit 1
}

# Create lands at <repo>/.worktrees/<name> on branch <name>, path on stdout.
path=$(jq -nc --arg cwd "$repo" '{name:"feat-x",cwd:$cwd}' | bash "$CREATE" 2>/dev/null)
[ "$path" = "$repo/.worktrees/feat-x" ] || {
  echo "expected $repo/.worktrees/feat-x, got: $path" >&2
  exit 1
}
[ "$(git -C "$path" symbolic-ref --short HEAD)" = "feat-x" ] || {
  echo "expected branch feat-x in the new worktree" >&2
  exit 1
}
[ "$(git -C "$path" rev-parse HEAD)" = "$(git -C "$repo" rev-parse origin/HEAD)" ] || {
  echo "expected feat-x to start at the freshly fetched origin/HEAD" >&2
  exit 1
}
[ "$(git -C "$path" rev-parse HEAD)" = "$(git --git-dir="$origin" rev-parse refs/heads/fresh-default)" ] || {
  echo "expected feat-x to use the remote's fresh default branch" >&2
  exit 1
}
if git -C "$repo" config --get branch.feat-x.remote >/dev/null; then
  echo "expected feat-x to have no upstream tracking branch" >&2
  exit 1
fi

# Create from inside an existing worktree still resolves the repo root.
path2=$(jq -nc --arg cwd "$path" '{name:"feat-y",cwd:$cwd}' | bash "$CREATE" 2>/dev/null)
[ "$path2" = "$repo/.worktrees/feat-y" ] || {
  echo "expected $repo/.worktrees/feat-y, got: $path2" >&2
  exit 1
}

# Reuse an existing local branch without fetching or changing its start point.
git -C "$repo" branch resume-x main
resume_base=$(git -C "$repo" rev-parse refs/heads/resume-x)
git -C "$repo" remote set-url origin "$TMPDIR/missing-origin.git"
resume_path=$(jq -nc --arg cwd "$repo" '{name:"resume-x",cwd:$cwd}' | bash "$CREATE" 2>/dev/null)
[ "$resume_path" = "$repo/.worktrees/resume-x" ] || {
  echo "expected existing branch resume-x to be reused" >&2
  exit 1
}
[ "$(git -C "$resume_path" rev-parse HEAD)" = "$resume_base" ] || {
  echo "expected resume-x to keep its existing local branch start point" >&2
  exit 1
}

# A failed fetch must fail closed without creating a branch or worktree.
fetch_stdout=$TMPDIR/fetch-failure.stdout
fetch_stderr=$TMPDIR/fetch-failure.stderr
if jq -nc --arg cwd "$repo" '{name:"fetch-fails",cwd:$cwd}' | bash "$CREATE" >"$fetch_stdout" 2>"$fetch_stderr"; then
  echo "expected WorktreeCreate to fail when fetching origin fails" >&2
  exit 1
fi
if [[ $(<"$fetch_stderr") != *"git fetch origin failed"* ]]; then
  echo "expected a clear fetch failure on stderr" >&2
  cat "$fetch_stderr" >&2
  exit 1
fi
[ ! -s "$fetch_stdout" ] || {
  echo "expected no stdout when fetching origin fails" >&2
  exit 1
}
[ ! -e "$repo/.worktrees/fetch-fails" ] || {
  echo "expected no worktree after fetch failure" >&2
  exit 1
}
if git -C "$repo" show-ref --verify --quiet refs/heads/fetch-fails; then
  echo "expected no branch after fetch failure" >&2
  exit 1
fi

# A successful fetch with no remote default must also fail closed.
git init -q --bare "$empty_origin"
git -C "$repo" remote set-url origin "$empty_origin"
head_stdout=$TMPDIR/head-failure.stdout
head_stderr=$TMPDIR/head-failure.stderr
if jq -nc --arg cwd "$repo" '{name:"head-fails",cwd:$cwd}' | bash "$CREATE" >"$head_stdout" 2>"$head_stderr"; then
  echo "expected WorktreeCreate to fail when origin/HEAD cannot be updated" >&2
  exit 1
fi
if [[ $(<"$head_stderr") != *"git remote set-head origin --auto failed"* ]]; then
  echo "expected a clear origin/HEAD failure on stderr" >&2
  cat "$head_stderr" >&2
  exit 1
fi
[ ! -s "$head_stdout" ] || {
  echo "expected no stdout when origin/HEAD cannot be updated" >&2
  exit 1
}
[ ! -e "$repo/.worktrees/head-fails" ] || {
  echo "expected no worktree after origin/HEAD failure" >&2
  exit 1
}
if git -C "$repo" show-ref --verify --quiet refs/heads/head-fails; then
  echo "expected no branch after origin/HEAD failure" >&2
  exit 1
fi

# Remove drops the worktree and its branch.
jq -nc --arg p "$path" '{worktree_path:$p}' | bash "$REMOVE" 2>/dev/null
[ ! -d "$path" ] || {
  echo "expected $path to be removed" >&2
  exit 1
}
if git -C "$repo" rev-parse --verify --quiet refs/heads/feat-x >/dev/null; then
  echo "expected branch feat-x to be deleted" >&2
  exit 1
fi

# Remove of an absent path is a no-op.
jq -nc '{worktree_path:"/nonexistent/wt"}' | bash "$REMOVE" 2>/dev/null

touch "$out"
