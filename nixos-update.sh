#!/usr/bin/env bash

set -euo pipefail

repo=/etc/nixos
host=nixos-dev

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: nixos-update <command>

Commands:
  prepare system  Update coordinated system inputs and validate the result.
  prepare brave   Update only the dedicated Brave input and validate it.
  publish         Commit the validated lockfile, push it, and open a PR.
  activate        Fast-forward clean master and install it for the next boot.
  cancel          Abandon an unpublished routine lockfile update.
  status          Show Git, generation, firmware, and service status.

Normal flow:
  nixos-update prepare system
  nixos-update publish
  # Review and merge the PR.
  nixos-update activate
  sudo reboot

NixOS model:
  prepare   moves flake.lock, then evaluates and builds without activation
  publish   records the exact dependency graph in Git for reproducibility
  activate  creates a boot generation without changing the running generation
  reboot    starts that generation; older generations remain rollback choices

Run a full system update every 2-4 weeks. Use `prepare brave` between full
updates when a browser security release needs to be picked up.
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

enter_clean_master() {
  cd "$repo"
  [[ "$(git branch --show-current)" == master ]] ||
    die "switch to master before starting an update"
  [[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] ||
    die "the repository is not clean; inspect it with: git -C $repo status -sb"

  git fetch origin master
  git merge --ff-only origin/master
}

validate_system() {
  printf '\n[validate 1/2] Evaluating the flake and its declared checks.\n'
  nix --option warn-dirty false flake check "$repo"
  printf '\n[validate 2/2] Realising the complete NixOS system closure.\n'
  nix --option warn-dirty false build --no-link \
    "$repo#nixosConfigurations.$host.config.system.build.toplevel"
  git -C "$repo" diff --check
}

prepare_update() {
  local mode="${1:-}"
  local branch

  case "$mode" in
    system | brave) ;;
    *) die "prepare requires either 'system' or 'brave'" ;;
  esac

  enter_clean_master
  branch="chore/update-$mode-$(date +%F)"

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    die "local branch already exists: $branch"
  fi
  if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    die "remote branch already exists: $branch"
  fi

  git switch -c "$branch"

  printf '\n[prepare] Updating pinned revisions in flake.lock.\n'
  printf 'This changes the declared inputs; it does not change the running system.\n\n'
  case "$mode" in
    system)
      nix flake update nixpkgs home-manager rust-overlay sops-nix --flake "$repo"
      ;;
    brave)
      nix flake update brave-nixpkgs --flake "$repo"
      ;;
  esac

  if git diff --quiet -- flake.lock; then
    printf 'No lockfile update was available. Returning to master.\n'
    git switch master
    git branch -d "$branch"
    exit 0
  fi

  validate_system

  printf '\nValidated update on %s.\n\n' "$branch"
  git diff --stat
  if [[ "$mode" == brave ]]; then
    printf 'Brave version: '
    nix --option warn-dirty false eval --raw \
      "$repo#nixosConfigurations.$host.pkgs.brave.version"
    printf '\n'
  fi
  printf '\nThe dirty lockfile is the validated candidate, not active system state.\n'
  printf 'Review the diff, then run: nixos-update publish\n'
  printf 'To abandon it instead, run: nixos-update cancel\n'
}

publish_update() {
  local branch status title summary pr_url

  cd "$repo"
  branch="$(git branch --show-current)"
  case "$branch" in
    chore/update-system-*)
      title='chore(nixos): update flake inputs'
      summary='Update the coordinated NixOS, Home Manager, Rust, and sops-nix inputs.'
      ;;
    chore/update-brave-*)
      title='chore(nixos): refresh Brave input'
      summary='Update the dedicated Brave nixpkgs input.'
      ;;
    *) die "publish must run from a branch created by nixos-update prepare" ;;
  esac

  status="$(git status --porcelain=v1 --untracked-files=all)"
  [[ "$status" == ' M flake.lock' ]] ||
    die "routine publishing accepts only one unstaged flake.lock change; inspect git status"

  validate_system
  printf '\n[publish] Recording the exact validated lockfile in Git.\n'
  git add -- flake.lock
  git commit -m "$title"
  git push -u origin "$branch"

  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    pr_url="$(gh pr list --repo suchapalaver/nixos-config --head "$branch" \
      --state open --json url --jq '.[0].url')"
    if [[ -z "$pr_url" ]]; then
      pr_url="$(gh pr create --repo suchapalaver/nixos-config --base master \
        --head "$branch" --title "$title" \
        --body "$summary

Validation:

- nix flake check
- full NixOS system closure build

Activation is intentionally deferred until after merge.")"
    fi
    printf '\nPull request: %s\n' "$pr_url"
  else
    printf '\nBranch pushed. Open a pull request against master.\n'
  fi

  printf 'Review and merge the PR, then run: nixos-update activate\n'
}

activate_update() {
  local branch pr_state

  cd "$repo"
  [[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] ||
    die "the repository is not clean; inspect it with: git -C $repo status -sb"

  branch="$(git branch --show-current)"
  git fetch origin master

  if [[ "$branch" != master ]]; then
    case "$branch" in
      chore/update-system-* | chore/update-brave-*) ;;
      *) die "activate accepts only master or a published update branch" ;;
    esac
    require_command gh
    pr_state="$(gh pr view "$branch" --repo suchapalaver/nixos-config \
      --json state --jq '.state')"
    [[ "$pr_state" == MERGED ]] ||
      die "the pull request for $branch is not merged"
    git switch master
  fi

  git merge --ff-only origin/master

  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/master)" ]] ||
    die "local master does not match origin/master"

  printf '\n[activate] Building a new immutable generation and making it the boot default.\n'
  printf 'The running generation is intentionally left unchanged until reboot.\n\n'
  sudo nixos-rebuild boot --flake "$repo#$host"
  printf '\nThe update is installed for the next boot. Reboot when ready:\n'
  printf '  sudo reboot\n'
}

cancel_update() {
  local branch status

  cd "$repo"
  branch="$(git branch --show-current)"
  case "$branch" in
    chore/update-system-* | chore/update-brave-*) ;;
    *) die "cancel must run from a branch created by nixos-update prepare" ;;
  esac

  status="$(git status --porcelain=v1 --untracked-files=all)"
  [[ "$status" == ' M flake.lock' ]] ||
    die "cancel accepts only one unstaged flake.lock change; inspect git status"

  git restore -- flake.lock
  git switch master
  git branch -d "$branch"
  printf 'Cancelled %s; master is clean and unchanged.\n' "$branch"
}

show_status() {
  local running next

  cd "$repo"
  git status -sb

  running="$(readlink -f /run/current-system)"
  next="$(readlink -f /nix/var/nix/profiles/system)"
  printf 'Running:   %s\n' "$running"
  printf 'Next boot: %s\n' "$next"
  if [[ "$running" == "$next" ]]; then
    printf 'Generation state: current (running and boot-default profiles match)\n'
  else
    printf 'Generation state: reboot pending (running system is still unchanged)\n'
  fi

  printf 'BIOS: '
  cat /sys/class/dmi/id/bios_version
  printf 'System: '
  systemctl is-system-running || true
  printf 'User: '
  systemctl --user is-system-running || true
  printf '/boot: '
  findmnt -no OPTIONS /boot
}

require_command git
require_command nix

case "${1:-}" in
  prepare)
    prepare_update "${2:-}"
    ;;
  publish)
    [[ $# -eq 1 ]] || die "publish takes no arguments"
    publish_update
    ;;
  activate)
    [[ $# -eq 1 ]] || die "activate takes no arguments"
    activate_update
    ;;
  cancel)
    [[ $# -eq 1 ]] || die "cancel takes no arguments"
    cancel_update
    ;;
  status)
    [[ $# -eq 1 ]] || die "status takes no arguments"
    show_status
    ;;
  help | --help | -h | '')
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
