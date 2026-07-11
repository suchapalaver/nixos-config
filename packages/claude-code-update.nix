{
  coreutils,
  curl,
  gnugrep,
  jq,
  nix,
  stdenv,
  writeShellApplication,
}:

let
  minVersion = "2.1.170";
  platformKey = "${stdenv.hostPlatform.node.platform}-${stdenv.hostPlatform.node.arch}";
in
writeShellApplication {
  name = "claude-code-update";
  runtimeInputs = [
    coreutils
    curl
    gnugrep
    jq
    nix
  ];
  text = ''
    set -euo pipefail

    NIXOS_FLAKE=/etc/nixos
    PIN_FILE="$NIXOS_FLAKE/pins/claude-code.nix"
    BASE_URL=https://downloads.claude.ai/claude-code-releases
    MIN_VERSION=${minVersion}
    PLATFORM_KEY=${platformKey}

    if [ "$#" -gt 1 ]; then
      echo "Usage: claude-code-update [version]"
      exit 2
    fi

    if [ "$#" -eq 1 ]; then
      target="$1"
    else
      target="$(curl -fsSL "$BASE_URL/latest" | tr -d '[:space:]')"
    fi

    if ! printf "%s\n" "$target" | grep -Eq '^[0-9]+[.][0-9]+[.][0-9]+$'; then
      echo "Refusing unexpected Claude Code version: $target"
      exit 1
    fi

    lowest="$(printf "%s\n%s\n" "$MIN_VERSION" "$target" | sort -V | head -n 1)"
    if [ "$lowest" != "$MIN_VERSION" ]; then
      echo "Refusing to pin Claude Code below $MIN_VERSION: $target"
      exit 1
    fi

    url="$BASE_URL/$target/$PLATFORM_KEY/claude"
    echo "Fetching Nix hash for Claude Code $target ($PLATFORM_KEY)..."
    prefetch_json="$(nix store prefetch-file --json "$url")"
    hash="$(printf "%s\n" "$prefetch_json" | jq -r .hash)"
    if [ -z "$hash" ] || [ "$hash" = "null" ]; then
      echo "Could not parse Nix hash from: $prefetch_json"
      exit 1
    fi

    echo "This will pin Claude Code $target in $PIN_FILE, update claude-code-nixpkgs, and rebuild nixos-dev."
    if current="$(claude --version 2>&1)"; then
      echo "Current Claude Code: $current"
    else
      echo "Current Claude Code check failed: $current"
    fi
    echo "New Claude Code: $target"
    echo "New source hash: $hash"

    printf "Continue? [y/N] "
    read -r answer
    case "$answer" in
      y|Y|yes|YES)
        ;;
      *)
        echo "Cancelled."
        exit 0
        ;;
    esac

    self_updated="$HOME/.local/bin/claude"
    if [ -L "$self_updated" ]; then
      shim_target="$(readlink "$self_updated")"
      case "$shim_target" in
        "$HOME"/.local/share/claude/versions/*)
          backup="$self_updated.self-updated.$(date +%Y%m%d%H%M%S)"
          mv "$self_updated" "$backup"
          echo "Moved self-updated Claude Code shim to $backup"
          ;;
      esac
    fi

    tmp="$(mktemp)"
    {
      printf "{\n"
      printf "  version = \"%s\";\n" "$target"
      printf "  hashes = {\n"
      printf "    \"%s\" = \"%s\";\n" "$PLATFORM_KEY" "$hash"
      printf "  };\n"
      printf "}\n"
    } > "$tmp"
    mv "$tmp" "$PIN_FILE"

    nix flake update claude-code-nixpkgs --flake "$NIXOS_FLAKE"
    /run/wrappers/bin/sudo /run/current-system/sw/bin/nixos-rebuild switch --flake "$NIXOS_FLAKE#nixos-dev"

    if current="$(claude --version 2>&1)"; then
      echo "Updated Claude Code: $current"
    else
      echo "Claude Code still failed after rebuild: $current"
      exit 1
    fi
  '';
}
