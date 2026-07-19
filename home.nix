{ config, pkgs, lib, ... }:

{
  # REQUIRED: set once; don't bump casually
  home.stateVersion = "25.05";

  # Optional: makes `home-manager` command available
  programs.home-manager.enable = true;

  # User packages
  home.packages = with pkgs; [
    # Applications
    obsidian
    whatsapp-electron
    discord
    (callPackage ./packages/claude-code-update.nix { })

    # Rust toolchain via rust-overlay
    (rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" ];
    })
    cargo-edit
    cargo-watch
    cargo-expand
    cargo-outdated
    cargo-audit
    cargo-generate
    cargo-nextest      # Better test runner (from macOS Brewfile)
    cargo-deny         # Dependency linting (from macOS Brewfile)
    cargo-machete      # Find unused dependencies (from macOS Brewfile)
    cargo-release      # Release automation (from macOS Brewfile)
    cargo-semver-checks # API compatibility (from macOS Brewfile)
    cargo-insta        # Snapshot testing (from macOS Brewfile)
    bacon              # Background rust code checker
    sccache            # Shared compilation cache

    # Editors (Cursor will be installed separately as it's not in nixpkgs yet)

    # Terminal tools
    starship
    zoxide             # Better cd
    eza                # Better ls
    bat                # Better cat
    ripgrep            # Better grep
    fd                 # Better find
    fzf                # Fuzzy finder
    jq                 # JSON processor
    yq                 # YAML processor
    httpie             # Better curl
    gh                 # GitHub CLI
    chezmoi            # Dotfile manager
    lazygit            # Git TUI
    delta              # Better git diff
    just               # Task runner (from macOS Brewfile)
    watchexec          # File watcher (from macOS Brewfile)
    mdbook             # Documentation builder (from macOS Brewfile)
    taplo              # TOML toolkit (from macOS Brewfile)

    # System monitoring
    htop
    btop
    ncdu
    duf                # Better df
    procs              # Better ps

    # Development tools
    direnv
    tmux
    tree
    tldr               # Better man pages
    tokei              # Code statistics
    shellcheck         # Shell script linter (from macOS Brewfile)
    git-filter-repo    # Git history rewriting (from macOS Brewfile)
    graphviz           # Graph visualization (from macOS Brewfile)
    plantuml           # UML diagrams (from macOS Brewfile)
    grpcurl            # gRPC CLI (from macOS Brewfile)
    cmake              # Build system
    gnumake            # Make

    # Container & Kubernetes tools
    podman
    podman-compose
    k3d                # k3s in Docker (from macOS Brewfile)
    kind               # Kubernetes in Docker (from macOS Brewfile)
    kubernetes-helm    # Kubernetes package manager (from macOS Brewfile)
    kubectl            # Kubernetes CLI

    # Python (for various tools)
    python3
    python3Packages.pip
    pipx               # Run Python apps in isolation (from macOS Brewfile)

    # Node.js & JavaScript
    nodejs
    pnpm               # Fast package manager (from macOS Brewfile)
    yarn               # Package manager (from macOS Brewfile)
    bun                # Fast JS runtime (from macOS Brewfile)

    # Blockchain development
    foundry            # Ethereum development toolkit (forge, cast, anvil, chisel)

    # GPG for commit signing
    gnupg
    pinentry-gnome3

    # Secrets management
    age
    sops

    # Infrastructure
    terraform          # Infrastructure as Code (from macOS Brewfile)
    tailscale          # VPN (from macOS Brewfile)

    # Database tools
    postgresql         # PostgreSQL client (from macOS Brewfile)
    redis              # Redis CLI (from macOS Brewfile)
  ];

  home.file = {
    ".local/bin/obsidian".source = "${pkgs.obsidian}/bin/obsidian-cli";
    ".local/bin/obsidian-app".source = "${pkgs.obsidian}/bin/obsidian";
  };

  # Global git ignore (aligned with macOS config)
  xdg.configFile."git/ignore".text = ''
    # Claude Code local settings
    **/.claude/settings.local.json

    # Common ignores
    .DS_Store
    *.swp
    *.swo
    *~
    .idea/
    .vscode/
    *.log
    .env.local
    .env.*.local
  '';

  # Git configuration
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
      syntax-theme = "Dracula";
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;  # Git LFS support
    settings = {
      user.name = "Joseph Livesey";
      user.email = "jlivesey@gmail.com";
      user.signingkey = "68CE9DFE49F46456";

      alias = {
        co = "checkout";
        ci = "commit";
        st = "status";
        br = "branch";
        hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
        type = "cat-file -t";
        dump = "cat-file -p";
        # Tree-like log with relative dates (aligned with macOS)
        lg = "log --graph --date=relative --pretty=tformat:'%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%an %ad)%Creset'";
        # List local commits not yet pushed (from macOS config)
        review-local = "!git lg @{push}..";
        # Quick append to .gitignore (from macOS config)
        ignore = "!f() { echo $1 >> .gitignore; }; f";
        # Custom GitHub clone alias - preserves org/user structure
        gh = "!f() { org=$(echo $1 | cut -d'/' -f1); repo=$(echo $1 | cut -d'/' -f2); mkdir -p $HOME/git/$org && cd $HOME/git/$org && git clone git@github.com:$1.git --recursive; }; f";
      };

      init.defaultBranch = "main";

      # Commit settings
      commit.gpgsign = true;

      # Push settings (aligned with macOS)
      push = {
        default = "current";
        autoSetupRemote = true;
      };

      # Pull settings (aligned with macOS)
      pull = {
        ff = "only";
        default = "current";
      };

      # Rebase settings (aligned with macOS)
      rebase = {
        autoSquash = true;
        gpgsign = true;
      };

      # Tag settings
      tag = {
        sort = "version:refname";
        gpgsign = true;
      };

      # Core settings
      core = {
        editor = "nvim";
        pager = "less -R";
        sshCommand = "ssh -F none -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes -o AddKeysToAgent=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o HashKnownHosts=yes";
        excludesfile = "~/.config/git/ignore";
      };

      # Log settings (cleaner output)
      log = {
        abbrevCommit = true;
        follow = true;
        decorate = false;
      };

      # Diff settings
      diff = {
        colorMoved = "default";
        mnemonicPrefix = true;
        tool = "vimdiff";
      };

      # Merge settings
      merge = {
        conflictstyle = "diff3";
        ff = false;
        tool = "vimdiff";
      };

      # Format settings (aligned with macOS)
      format.signoff = true;

      color.ui = "auto";

      credential.helper = "cache --timeout=3600";

      # Use SSH for GitHub
      url."ssh://git@github.com/" = {
        insteadOf = "https://github.com/";
      };

      # GPG program path (for when signing is enabled)
      gpg.program = "${pkgs.gnupg}/bin/gpg";
    };
  };

  # GPG configuration for commit signing
  programs.gpg = {
    enable = true;
  };
  
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    # History configuration
    history = {
      size = 100000;
      save = 100000;
      path = "$HOME/.zsh_history";
      ignoreDups = false;  # Keep duplicates for better predictions
      share = true;  # Share history between sessions immediately
    };
    
    # Enhanced history settings
    historySubstringSearch = {
      enable = true;
    };
    
    shellAliases = {
      ll = "eza -l";
      la = "eza -la";
      lt = "eza --tree";
      cat = "bat";
      grep = "rg";
      find = "fd";
      cd = "z";

      # Docker -> Podman (aligned with macOS)
      docker = "podman";

      # Git aliases
      g = "git";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gd = "git diff";
      gco = "git checkout";
      gcb = "git checkout -b";
      glg = "git lg";  # Tree-like log
      grl = "git review-local";  # Review unpushed commits

      # Nix aliases
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos-dev";
      update = "\\cd /etc/nixos && sudo nix flake update && \\cd -";
      claude-update = "claude-code-update";
      codex-update = "npm install --global @openai/codex@latest && codex --version";
      update-ai = "claude-code-update && npm install --global @openai/codex@latest && claude --version && codex --version";
      garbage = "sudo nix-collect-garbage -d";

      # Rust aliases
      cb = "cargo build";
      cr = "cargo run";
      ct = "cargo test";
      cc = "cargo check";
      cw = "cargo watch";
      cf = "cargo fmt";
      clippy = "cargo clippy -- -W clippy::pedantic";
      ctn = "cargo nextest run";  # Better test runner

      # Foundry/EVM aliases
      ftest = "forge test";
      fbuild = "forge build";
      fscript = "forge script";

      # Application aliases
      whatsapp = "whatsapp-electron";
      obs = "obsidian";
      obsapp = "obsidian-app";
      obsd = "obsidian daily";
      obsa = "obsidian daily:append";
      obsr = "obsidian search";
      obsu = "obsidian unresolved";
      obso = "obsidian orphans";
    };
    
    initContent = lib.mkMerge [
      (lib.mkOrder 1000 ''
      # Add paths
      export PATH="$HOME/.npm-global/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.foundry/bin:$PATH"  # Foundry (forge, cast, anvil, chisel)

      # GPG TTY for commit signing (aligned with macOS)
      export GPG_TTY=$(tty)

      # Load secrets from sops-nix
      [[ -r /run/secrets/openai_api_key ]] && export OPENAI_API_KEY="$(cat /run/secrets/openai_api_key)"

      # Note: starship and direnv zsh integration are handled automatically by
      # programs.starship.enable / programs.direnv.enable (enableZshIntegration
      # defaults to true), so no manual `eval` is needed here.

      # Enhanced history settings
      setopt HIST_IGNORE_ALL_DUPS  # Delete old recorded entry if new entry is a duplicate
      setopt HIST_SAVE_NO_DUPS     # Don't write duplicate entries in the history file
      setopt HIST_REDUCE_BLANKS    # Remove superfluous blanks before recording entry
      setopt HIST_VERIFY           # Don't execute immediately upon history expansion
      setopt INC_APPEND_HISTORY    # Write to the history file immediately
      setopt SHARE_HISTORY         # Share history between all sessions
      setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history
      
      # Better completion
      setopt COMPLETE_IN_WORD      # Complete from both ends of a word
      setopt ALWAYS_TO_END         # Move cursor to the end of a completed word
      setopt PATH_DIRS             # Perform path search even on command names with slashes
      setopt AUTO_MENU             # Show completion menu on a successive tab press
      setopt AUTO_LIST             # Automatically list choices on ambiguous completion
      setopt AUTO_PARAM_SLASH      # If completed parameter is a directory, add a trailing slash
      setopt MENU_COMPLETE         # Cycle through completions on tab
      
      # Predictive suggestions configuration
      ZSH_AUTOSUGGEST_STRATEGY=(history completion)
      ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
      ZSH_AUTOSUGGEST_USE_ASYNC=true
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
      
      # Key bindings for history substring search
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      bindkey '^P' history-substring-search-up
      bindkey '^N' history-substring-search-down
      
      # Accept autosuggestion with right arrow
      bindkey '^ ' autosuggest-accept
      bindkey '^[[C' forward-char
      
      # Fuzzy history search with fzf
      fzf-history-widget() {
        local selected num
        setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
        selected=( $(fc -rl 1 | awk '{ cmd=$0; sub(/^[ \t]*[0-9]+\*?[ \t]+/, "", cmd); if (!seen[cmd]++) print $0 }' |
          FZF_DEFAULT_OPTS="--height 40% --reverse --tiebreak=index --bind=ctrl-r:toggle-sort,ctrl-z:ignore $FZF_DEFAULT_OPTS --query=$LBUFFER" fzf) )
        local ret=$?
        if [ -n "$selected" ]; then
          num=$selected[1]
          if [ -n "$num" ]; then
            zle vi-fetch-history -n $num
          fi
        fi
        zle reset-prompt
        return $ret
      }
      zle -N fzf-history-widget
      bindkey '^R' fzf-history-widget
      
      # Better history
      HISTSIZE=10000
      SAVEHIST=10000
      setopt HIST_IGNORE_DUPS
      setopt HIST_IGNORE_SPACE
      setopt SHARE_HISTORY
      
      # FZF keybindings
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
      
      # Custom functions
      mkcd() {
        mkdir -p "$1" && cd "$1"
      }
      
      # Rust development helpers
      new_rust_project() {
        cargo new "$1" && cd "$1" && git init
      }
      
      # Quick GitHub clone to ~/git/org/repo structure
      ghclone() {
        local org=$(echo $1 | cut -d'/' -f1)
        local repo=$(echo $1 | cut -d'/' -f2)
        mkdir -p ~/git/$org
        cd ~/git/$org
        git clone "git@github.com:$1.git" --recursive
        cd $repo
      }
      
      # Setup GPG key (helper function)
      setup_gpg() {
        echo "Generating GPG key for git commit signing..."
        gpg --full-generate-key
        echo ""
        echo "Your GPG keys:"
        gpg --list-secret-keys --keyid-format LONG
        echo ""
        echo "To enable commit signing, add this to your git config:"
        echo "  git config --global user.signingkey YOUR_KEY_ID"
        echo "  git config --global commit.gpgsign true"
      }

      # Obsidian helpers
      obsn() {
        obsidian create "$@"
      }

      obsdump() {
        local out_file="$1"
        shift
        "$@" > "$out_file"
      }

      obscap() {
        local note_path="$1"
        shift
        local output
        output="$("$@")" || return $?
        obsidian append path="$note_path" content="$output"
      }
      '')

      # Initialize zoxide dead last — home-manager sources zsh-syntax-highlighting
      # (order 1200) and zsh-history-substring-search (1250) after the default
      # initContent (1000). mkAfter (1500) ensures zoxide's hooks aren't clobbered.
      (lib.mkAfter ''
        eval "$(zoxide init zsh)"
      '')
    ];
  };

  # Starship prompt configuration
  programs.starship = {
    enable = true;
    settings = {
      format = ''
        [╭─](bold green)$username$hostname$directory$git_branch$git_status$rust$nodejs$python$nix_shell
        [╰─](bold green)$character
      '';
      
      username = {
        show_always = false;
        format = "[$user]($style) @ ";
      };
      
      hostname = {
        ssh_only = false;
        format = "[$hostname]($style) in ";
        style = "bold dimmed green";
      };
      
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "bold cyan";
      };
      
      git_branch = {
        style = "bold purple";
      };
      
      git_status = {
        style = "bold red";
      };
      
      rust = {
        format = "via [$symbol($version)]($style) ";
        style = "bold red";
      };
      
      nix_shell = {
        format = "via [$symbol$state]($style) ";
        symbol = "❄️ ";
      };
    };
  };

  # Direnv configuration
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Tmux configuration (aligned with macOS config)
  programs.tmux = {
    enable = true;
    clock24 = true;
    escapeTime = 10;  # Remove delay for ESC in Neovim
    baseIndex = 1;
    keyMode = "vi";
    prefix = "C-a";  # Use C-a instead of C-b (aligned with macOS)
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      vim-tmux-navigator  # Seamless vim/tmux navigation (from macOS)
      {
        plugin = resurrect;  # Persist sessions after restart (from macOS)
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;  # Auto-save sessions every 15 min (from macOS)
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
      {
        plugin = dracula;
        extraConfig = ''
          set -g @dracula-show-battery true
          set -g @dracula-show-powerline true
          set -g @dracula-refresh-rate 10
        '';
      }
    ];

    extraConfig = ''
      # True color support
      set -ag terminal-overrides ",xterm-256color:RGB"

      # Mouse support
      set -g mouse on

      # Better split keys (aligned with macOS)
      unbind %
      bind | split-window -h
      unbind '"'
      bind - split-window -v

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # Vim-style pane resizing (from macOS)
      bind j resize-pane -D 5
      bind k resize-pane -U 5
      bind l resize-pane -R 5
      bind h resize-pane -L 5

      # Maximize pane toggle
      bind -r m resize-pane -Z

      # Vi copy mode bindings (from macOS)
      bind-key -T copy-mode-vi 'v' send -X begin-selection
      bind-key -T copy-mode-vi 'y' send -X copy-selection

      # Don't exit copy mode when dragging with mouse
      unbind -T copy-mode-vi MouseDragEnd1Pane

      # Status bar position
      set -g status-position top
    '';
  };

  # FZF configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout reverse"
      "--border"
      "--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
    ];
  };

  # Bat configuration
  programs.bat = {
    enable = true;
    config = {
      theme = "Dracula";
      style = "numbers,changes,header";
    };
  };

  # Neovim is configured via init.lua file below

  # SSH configuration (using new settings API)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        HashKnownHosts = true;
      };
      "github.com" = {
        Hostname = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
        AddKeysToAgent = "yes";
      };
    };
  };

  # npm configuration for global packages
  home.file.".npmrc".text = ''
    prefix=~/.npm-global
  '';

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    BROWSER = "brave";
    TERMINAL = "alacritty";
    
    # Rust environment
    CARGO_HOME = "$HOME/.cargo";
    
    # Development
    PROJECTS = "$HOME/projects";
    
    # GPG TTY for commit signing
    GPG_TTY = "$(tty)";
  };

  # Create common directories
  home.file.".config/.keep".text = "";
  home.file."projects/.keep".text = "";
  home.file."git/.keep".text = "";
  home.file.".local/bin/.keep".text = "";
  
  # Link Neovim configuration
  home.file.".config/nvim/init.lua".source = ./nvim-config.lua;
}
