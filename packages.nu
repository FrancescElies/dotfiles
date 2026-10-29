# Package definitions (converted from packages.toml)
# Keep comments for documentation

export const packages = {
    python-tools: [
        "cogapp"  # generate content with inlined Python code. https://nedbatchelder.com/code/cog
        "honcho"  # Foreman clone, manage Procfile apps
        "img2pdf"  # lossless conversion of rater images to pdf
        "jrnl"  # Collect your thoughts and notes without leaving the command line
        "keyring"  # cli and lib to easyly access the system keyring
        "litecli"  # CLI for SQLite Databases with auto-completion and syntax highlighting
        "magic-wormhole"  # get things from one computer to another, safely
        "ocrmypdf"  # adds OCR layer to scanned PDF files, allowing them to be searched
        "semble"  # natural language processing
        "weasyprint"  # helping web developers to create PDF documents. It turns simple HTML pages into gorgeous statistical reports, invoices, tickets
        "toolong"  # textualize: terminal application to view, tail, merge, and search log files (plus JSONL).
        "yt-dlp"  # audo video downloader
    ]

    python: [
        "aw-client"  # client library for activitywatch
        "hypothesis"  # find edge cases in your code
        "MechanicalSoup"  # automate interaction with websites, (no Javascript, for js see Selenium)
        "frida-tools"  # dynamic instrumentation toolkit for devs
        "ipython"  # repl
        "ipdb"  # better pdb
        "chardet"  # character encoding detector
        "pytextrank"  # TextRank algorithms (textgraphs) for phrase extraction
        "yake"  # yet another keyword extractor (extract most important keywords from a document)
        "spacy"  # natural language processing
        "python-benedict"  # dict subclass with keylist/keypath support, built-in I/O operations (base64, csv, html, ini, json, pickle, plist, query-string, toml, xls, xml, yaml), s3 support and many utilities.
    ]

    rust-pkgs: [
        "aichat"  # LLM CLI tool
        "coreutils"  # Cross-platform rewrite of GNU coreutils
        "lstr"  # tree viewer
        "tree-sitter-cli"  # Tree-sitter grammars from the command line
        "bat"  # cat clone
        "bandwhich"  # display current network utilization by process, connection and remote host
        "bottom"  # graphical process/system monitor for the terminal.
        "heatseeker"  # fuzzy selector, a selecta clone
        "broot"  # explore file hierarchies with a tree-like view
        "difftastic"  # structural diff tool
        "diskonaut"  # find whale files that eat up disk space
        "fclones"  # finds and removes duplicate files
        "fd-find"  # find entries in your filesystem
        "gimoji"  # copy emoji to clipboard, or add them to commit messages
        "just"  # just a command runner https://github.com/casey/just
        "gitu"  # git client inspired by Magit
        "ripgrep_all"  # ripgrep, but also search in PDFs, E-Books, Office documents, zip, tar.gz, etc.
        "killport"  # kill processes running on specified port
        "kondo"  # Kondo recursively cleans project directories.
        "miniserve"  # serve some files over HTTP right now!
        "mprocs"  # tui for running multiple processes
        "nu"  # nushell language and shell
        "ouch"  # extract/compress files
        "pgen"  # passphrase generator
        "rustscan"  # network scanner
        "tailspin"  # log file highlighter
        "tealdeer"  # TLDR client
        "xh"  # http requests
    ]

    rust-dev-pkgs: [
        "flamegraph"  # cargo flamegraph, flamegraph -- /path/to/binary
        "hotpath"  # Profile CPU, memory, async execution, SQL and HTTP calls, I/O streams, lock contention and channels from a single tool
        "amber"  # replace things in files (sed like tool)
        "ast-grep"  # Search and Rewrite code at large scale using precise AST pattern
        "bacon"  # watches your rust project and runs jobs in background
        "cargo-binutils"  # LLVM tools for cargo
        "cargo-edit"  # commands for modifying cargo.toml
        "cargo-expand"  # expand rust macros
        "cargo-info"  # query crates.io for crate details
        "cargo-mutants"  # injects bugs and see if tests catch them
        "cargo-sweep"  # cleans unused build files created by cargo
        "cargo-udeps"  # find unused dependencies
        "cargo-update"  # update dependencies as recorded in local lock file
        "cargo-watch"  # watch over cargo project
        "checkexec"  # conditionally execute commands only when files in a dependency list have been updated
        "fastmod"  # replace for programmers
        "fnm"  # node.js manajer
        "git-absorb"  # git commit --fixup, but automatic
        "git-delta"  # syntax-highlighting pager for git
        "huniq"  # remove duplicates from input
        "mdbook"  # creates book from markdown files
        "rathole"  # expose a service NAT to the Internet (like ngrok)
        "samply"  # cli sampling profiler, check performance, something hangs?
        "sccache"  # build caching tool
        "secure_remove"  # securely remove files and dirs
        "tokei"  # count lines of code
        "watchexec-cli"  # execute commands in response to modifications
    ]

    fedora: [
        "age"  # modern secure encryption tool
        "hfsplus-tools"  # HFS+, HFS Plus, or Mac OS Extended the apple computer filesystem
        "bat"  # better cat
        "cascadia-mono-nf-fonts"  # cascadia with nerdfont
        "curl"  # cli data transfer
        "fd-find"  # a better find
        "flameshot"  # screenshot tool# powerful yet simple screenshots
        "gh"  # GitHub CLI# github cli
        "git"  # version control# git
        "golang"  # go programming language
        "gron"  # make json grppable
        "just"  # command runner
        "mupdf"  # lightweight pdf viewer and toolkit
        "nmap"  # netwrork scanner
        "restic"  # backup tool# backup  things
        "ripgrep"  # fast grep# a better grep
        "rustup"  # manage rust toolchains
        "sshfs"  # mount remote locations via ssh
        "syncthing"  # continuous file synchronization
        "tealdeer"  # tldr commands
        "thunderbird"  # mail reader
        "wireguard-tools"  # vpn
    ]

    debian: [
        "age"  # modern secure encryption tool
        "bat"  # better cat
        "build-essential"  # compiler and build tools
        "ntpsec-ntpdate"  # set system time using Network Time Protocol
        "cmake"  # cmake
        "golang"  # go programming language
        "curl"  # cli data transfer
        "fail2ban"  # ban brute-force attackers
        "fd-find"  # a better find
        "ffmpeg"  # format media conversion
        "flameshot"  # screenshot tool# powerful yet simple screenshots
        "gh"  # GitHub CLI# github cli
        "git"  # version control# git
        "gron"  # make json grppable
        "mupdf"  # lightweight pdf viewer and toolkit
        "nmap"  # netwrork scanner
        "printer-driver-splix"  # samsung drivers
        "restic"  # backup tool# backup things
        "rfkill"  # enable/disable wireless devices
        "ripgrep"  # fast grep# a better grep
        "rsync"  # backup things
        "sshfs"  # mount remote locations via ssh
        "syncthing"  # continuous file synchronization
        "vlc"  # media player# media player
        "printer-driver-all"  # many printer drivers
        "openprinting-ppds"  # printer drivers
        "avahi-utils"  # publish and discover services, e.g. printers
    ]

    windows: [
        ""ArtifexSoftware.mutool""  # lightweight pdf viewer and toolkit
        ""7zip.7zip""  # archive tool
        ""Flow-Launcher.Flow-Launcher""  # quick file search and app launcher
        ""voidtools.everything""  # file indexer and search
        ""FiloSottile.age""  # modern secure encryption tool
        ""Audacity.Audacity""  # audio editor
        ""BurntSushi.ripgrep.MSVC""  # fast grep
        ""Casey.Just""  # command runner
        ""DBBrowserForSQLite.DBBrowserForSQLite""  # sqlite browser
        ""Flameshot.Flameshot""  # powerful yet simple screenshots
        ""GIMP.GIMP""  # image editor
        ""Git.Git""  # version control
        ""GitHub.GitHubDesktop""  # GitHub GUI
        ""GitHub.GitLFS""  # large file storage
        ""GitHub.cli""  # GitHub CLI
        ""GoLang.Go""  # go programming language
        ""Graphviz.Graphviz""  # graph visualization
        ""JesseDuffield.lazygit""  # terminal UI for git
        ""KeePassXCTeam.KeePassXC""  # password manager
        ""Kitware.CMake""  # build system
        ""Microsoft.AzureCLI""  # Azure CLI
        ""Microsoft.VisualStudioCode""  # code editor
        ""Mozilla.SOPS""  # editor of encrypted files that supports YAML, JSON, ENV, INI and BINARY formats and encrypts with AWS KMS, GCP KMS, Azure Key Vault, age, and PGP
        ""Neovide.Neovide""  # neovim GUI
        ""Ninja-build.Ninja""  # build system
        ""Nushell.Nushell""  # shell
        ""OBSProject.OBSStudio""  # streaming/recording
        ""Python.Python.3.12""  # python
        ""sylikc.JPEGView""  # fast image viewer
        ""DuongDieuPhap.ImageGlass""  # another fast image viewer
        ""Rustlang.Rustup""  # rust toolchain
        ""SumatraPDF.SumatraPDF""  # pdf viewer# pdf viewer
        ""Terrastruct.D2""  # text to diagrams# turns text to diagrams
        ""TomHudson.gron""  # make json grepable# make json grppable
        ""VideoLAN.VLC""  # media player
        ""bmatzelle.Gow""  # unix tools for windows
        ""mesonbuild.meson""  # build system# build system
        ""sharkdp.fd""  # fast find# fd find
        ""wez.wezterm""  # terminal# terminal
        ""x64dbg.x64dbg""  # debugger# debugger
    ]

    mac-brew: [
        "fd"  # fast find alternative
        "gh"  # GitHub CLI
        "git"  # version control
        "lazygit"  # terminal UI for git
        "restic"  # backup tool
        "ripgrep"  # fast grep
        "vlc"  # media player
        "battery"  # manage/limit battery charging (M1, M2, M3)
    ]

    mac-brew-cask: [
        "flameshot"  # screenshot tool
        "gimp"  # image editor
        "obs"  # streaming/recording
        "vlc"  # media player
        "wezterm"  # terminal emulator
        "bitwarden"  # password manager
        ""nikitabobko/tap/aerospace""  # i3 like window manager
    ]

    go-install: [
        ""github.com/aandrew-me/tgpt/v2@latest""
    ]

    apt: [
        "sccache"  # compiler cache for C/C++/Rust
    ]

}
