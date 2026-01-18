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
    bacon  # Background rust code checker
    sccache  # Shared compilation cache

    # Editors (Cursor will be installed separately as it's not in nixpkgs yet)

    # Terminal tools
    starship
    zoxide  # Better cd
    eza  # Better ls
    bat  # Better cat
    ripgrep  # Better grep
    fd  # Better find
    fzf  # Fuzzy finder
    jq  # JSON processor
    yq  # YAML processor
    httpie  # Better curl
    gh  # GitHub CLI
    lazygit  # Git TUI
    delta  # Better git diff

    # System monitoring
    htop
    btop
    ncdu
    duf  # Better df
    procs  # Better ps

    # Development tools
    direnv
    tmux
    tree
    tldr  # Better man pages
    tokei  # Code statistics

    # Container tools
    podman
    podman-compose

    # Python (for various tools)
    python3
    python311Packages.pip
    
    # Blockchain development
    foundry  # Ethereum development toolkit (forge, cast, anvil, chisel)
    
    # GPG for commit signing
    gnupg
    pinentry-gnome3
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Joseph Livesey";
    userEmail = "jlivesey@gmail.com";
    
    # Enable delta for better diffs
    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "Dracula";
      };
    };
    
    # Git aliases
    aliases = {
      co = "checkout";
      ci = "commit";
      st = "status";
      br = "branch";
      hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
      type = "cat-file -t";
      dump = "cat-file -p";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      # Custom GitHub clone alias - preserves org/user structure
      gh = "!f() { org=$(echo $1 | cut -d'/' -f1); repo=$(echo $1 | cut -d'/' -f2); mkdir -p $HOME/git/$org && cd $HOME/git/$org && git clone git@github.com:$1.git --recursive; }; f";
    };
    
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      color.ui = "auto";
      
      core = {
        editor = "nvim";
        sshCommand = "ssh -i ~/.ssh/id_ed25519";
      };
      
      credential = {
        helper = "cache";
      };
      
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
      
      # Use SSH for GitHub
      url."ssh://git@github.com/" = {
        insteadOf = "https://github.com/";
      };
      
      # GPG signing configuration (commented out until GPG key is set up)
      # commit.gpgsign = true;
      # user.signingkey = "YOUR_GPG_KEY_ID";
      # gpg.program = "${pkgs.gnupg}/bin/gpg";
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
      
      # Nix aliases
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos-dev";
      update = "\\cd /etc/nixos && sudo nix flake update && \\cd -";
      garbage = "sudo nix-collect-garbage -d";
      
      # Rust aliases
      cb = "cargo build";
      cr = "cargo run";
      ct = "cargo test";
      cc = "cargo check";
      cw = "cargo watch";
      cf = "cargo fmt";
      clippy = "cargo clippy -- -W clippy::pedantic";
    };
    
    initContent = ''
      # Set up zoxide
      eval "$(zoxide init zsh)"
      
      # Set up starship
      eval "$(starship init zsh)"
      
      # Set up direnv
      eval "$(direnv hook zsh)"
      
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
    '';
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

  # Tmux configuration
  programs.tmux = {
    enable = true;
    clock24 = true;
    escapeTime = 0;
    baseIndex = 1;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
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
      # Mouse support
      set -g mouse on
      
      # Better split keys
      bind | split-window -h
      bind - split-window -v
      
      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"
      
      # Status bar
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

  # SSH configuration
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    extraConfig = ''
      Host *
        ServerAliveInterval 60
        ServerAliveCountMax 3
      
      Host github.com
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_ed25519
        AddKeysToAgent yes
    '';
  };

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