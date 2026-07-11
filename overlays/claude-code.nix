{ claude-code-nixpkgs }:

final: prev:

let
  pin = import ../pins/claude-code.nix;
  platformKey = "${prev.stdenv.hostPlatform.node.platform}-${prev.stdenv.hostPlatform.node.arch}";
  claudePkgs = import claude-code-nixpkgs {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  claude-code = claudePkgs.claude-code.overrideAttrs (_finalAttrs: _previousAttrs: {
    version = pin.version;
    src = prev.fetchurl {
      url = "https://downloads.claude.ai/claude-code-releases/${pin.version}/${platformKey}/claude";
      hash = pin.hashes.${platformKey} or (throw "No Claude Code hash pinned for ${platformKey}");
    };
  });
}
