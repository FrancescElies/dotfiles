# my notes
use git-aliases.nu *
export alias ex = explore
export alias ll = ls -l

export def "aptf search" [] {
    apt-cache search . |fzf --multi | lines | parse "{package} - {description}"
}

export def "aptf install" [] {
    sudo apt install ...(aptf search | get package)
}

# ripgrep->fzf->vim [QUERY]
export def rg-fzf-nvim [] {
    let RELOAD = 'rg --column --color=always --smart-case {q}'
    let OPENER = '
        if $env.FZF_SELECT_COUNT == 0 {
            nvim {1} +{2}     # No selection. Open the current line in Vim.
        } else {
            nvim +cw -q {+f}  # Build quickfix list for the selected items.
        }
    '
    # 1. Search for text in files using Ripgrep
    # 2. Interactively restart Ripgrep with reload action
    #    * Press alt-enter to switch to fzf-only filtering
    # 3. Open the file in Vim
    ( fzf --disabled --ansi --multi
        --bind $"start:reload:($RELOAD)"
        --bind $"change:reload:($RELOAD)"
        --bind $"enter:become:($OPENER)"
        --bind $"ctrl-o:execute:($OPENER)"
        --bind 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-/:toggle-preview'
        --bind 'ctrl-f:unbind(change,alt-enter)+change-prompt(2. (ctrl-f [f]ind-toggle) fzf> )+enable-search+clear-query'
        --prompt '1. (ctrl-f [f]ind-toggle) ripgrep> '
        --delimiter ':'
        --preview 'bat --style=full --color=always --highlight-line {2} {1}'
        --preview-window '~4,+{2}+4/3,<80(up)'
        --query "$*" )
}
# ripgrep->fzf->vim [QUERY]
export alias rfv = rg-fzf-nvim

export alias lg = lazygit

# # something like gron
# export def gronu [] {
#     use std-rfc/iter recurse
#     $in | recurse | update item { to nuon }
# }

export alias todos = nvim ~/src/_notes/src/todos.md

# # create big file
# export def "my create big-file" [filesize: filesize, outfile: path = bigfile.txt] {
#     use std repeat
#     "a" | std repeat (128kib | into int) | str join "" o> $outfile
# }

export alias pipx = python ~/bin/pipx.pyz

# list open listening ports
export def "my open-ports" [] {
  match $nu.os-info.name {
      "windows" => { error make {msg: "netstat -tulnp ???"} },
      # netstat columns in unix
      # Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID Program name
      _ => { netstat -tulnp | str replace -a "/" " " | str replace "Program name" " program-name" | tail -n +2 | detect columns },
  }
}

# extracts archives with different extensions
export alias decompress = ouch decompress
# extracts archives
export def "decompress all" [path: path = "."] {
    cd $path
    ( ls *[tar, zip, bz, bz2, gz, lz4, xz, lzma, tgz, tbz, tlz4, txz, tzlma, tsz, tzst sz, zst, rar]
    | each { ouch decompress $in.name })
}

export def "my wezterm logs" [] {
  if $nu.os-info.name == "linux" {
    br $env.XDG_RUNTIME_DIR/wezterm
  } else {
    br ~/.local/share/wezterm/
  }
}

export def "my time-today" [] {
    cd ~
    python ~/src/dotfiles/config/nushell/src/time_spent_today.py
}

# list services (printers, scanners...) in local network with avahi-browse
export def "my network services" [] {
 avahi-browse --all --terminate --parsable
  | from csv --separator ";" --noheaders --flexible
  | rename "new(+)\ngone(-)\nresolved(=)" net IPvX ip service-type domain
}

# list printers in local network with avahi-browse
export def "my network printers" [] {
 avahi-browse --terminate --parsable _ipp._tcp
  | from csv --separator ";" --noheaders --flexible
  | rename "new(+)\ngone(-)\nresolved(=)" net IPvX ip service-type domain
}


# compact ls
export def lsg [] { try { ls | sort-by type name -r | grid --icons --color | str trim } catch { ls | get name | to text} }
export alias l = lsg

# cd to the folder where a binary is located
export def --env "cd where-is" [program] {
  let dir = (which $program | get path | path dirname | str trim)
  cd $dir.0
}

# date string YYYY-MM-DD
export def "date format ymd" [] { (date now | format date %Y-%m-%d) }

# date string DD-MM-YYYY
export def "date format dmy" [] { (date now | format date %d-%m-%Y) }

# create directory and cd into it (alias mcd)
export def --env mkdircd [dir: path] { mkdir $dir; cd $dir }
alias mcd = mkdircd

#compress to 7z using max compression
export def `7z compress max` [
  outfile: string  # out filename without extension
  ...rest:  string  # files to compress and extra flags for 7z (add flags between quotes)
  #
  # Example:
  # compress all files in current directory and delete them
  # 7zmax * "-sdel"
] {

  if ($rest | is-empty) {
    print "no files to compress specified"
  } else {
     7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on $"($outfile).7z" ...$rest
  }
}

# print worth watching speakers
export def "my speakers" [] {
  return {
    python: "David Beazley, Raymond Hettinger, Hynek Schlawack"
    rust: "Jon Gjengset"
  }
}

# what is my public ip
export def "my ip" [] {
  http get https://ipinfo.io/json
  # http get https://api.ipify.org
  # http get https://api6.ipify.org
}

# which apps do I have
export def "my apps" [] {
  let venv_pkgs = (python -c `from importlib.metadata import entry_points; print('\n'.join(x.name for x in entry_points()['console_scripts']))` | lines)
  let bin_pkgs = (try {ls ~/bin/**/*} catch {[]} | where type == file | get name)
  let cargo_bin_pkgs = (try {ls ~/.cargo/bin/*} catch {[]} | where type == file | get name)
  let go_bin_pkgs = (try {ls ~/go/bin/*} catch {[]} | where type == file | get name)
  return ($venv_pkgs | append $bin_pkgs | append $cargo_bin_pkgs | append $go_bin_pkgs
        | path parse | flatten | move stem --first | move extension --after stem
    )
}

def "my compiler-flags" [] {
    print https://youtu.be/YXrb-DqsBNU?feature=shared&t=546
    print https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html#available-checks
    print "-Werror -Wall -Wextra -fsanitize=address,undefined,float-divide-by-zero,unsigned-integer-overflow,implicit-conversion,local-bounds,nullability"
}

# backup by-year
export def "my backup by-year" [serverip: string = "intel-pc"] {
    restic --repo sftp:($serverip):by-year.restic backup ~/by-year
}

export def "my backup restore by-year" [serverip: string = "intel-pc"] {
    restic --repo sftp:($serverip):by-year.restic restore ~/by-year
}

#
# neovim
#
export alias e = nvim
export alias ee = nvim -u ~/src/kickstart.nvim/minimal-vimrc.vim
export alias "nvim emergency" = nvim -u ~/src/kickstart.nvim/minimal-vimrc.vim
export def "nvim clean shada" [] {
    match $nu.os-info.name {
        "windows" => { fd swp ~/AppData/Local/nvim-data/swap -x rm },
        _ => { rm -rf ~/.local/state/nvim/shada },
    }
}
export def "nvim clean swap" [] {
    match $nu.os-info.name {
        "windows" => { fd swp ~/AppData/Local/nvim-data/swap -x rm },
        _ => { fd swp ~/.local/state/nvim/swap -x rm },
    }
}
export def "nvim pr-files" [] { nvim ...(git pr files) }

export def "nvim server" [] {
    nvim --listen ~/.cache/nvim/server.pipe --headless
}
export def "nvim client" [...file: path] {
    nvim --remote --server ~/.cache/nvim/server.pipe ...$file
}


#
# process
#
# fuzzy select find process pid
export def pid [] { ps | sort-by -in name | input list -d name --fuzzy  | get pid }

# gets pid of process with name
export def pidof [name: string ] {
  let procs = ps --long | where name =~ $name
  if (($procs | length) > 1) {
    $procs | sort-by -in name | input list -d name --fuzzy | get pid
  } else {
    $procs | get 0.pid
  }
}

# grep for specific process names
export def "ps name" [name: string = "" ] {
  if ($name | is-empty) {
    ps --long | sort-by -in name | input list -d name --fuzzy
  } else {
    ps --long | find --ignore-case --columns [name] -i $name
  }
}
export alias psn = ps name

# get the counts of the multiset processes
export def "ps count" [] {
    ps | get name | uniq --count | sort-by count | rename name count
}
export alias psc = ps count

def "nu-complete list-process-names" [] { ps | get name | sort | uniq }

# kill specified process with substring
export def "ps kill-name" [...names: string@"nu-complete list-process-names"] {
    for name in $names {
        let procs = ps | find --ignore-case --columns [name] $name | sort-by -in name
        print $procs
        $procs | each { try { kill -f $in.pid } }
    }
}
export alias killn = ps kill-name

# copilot
export def hey [...words: string] {
    # maybe use other elia, tgpt, aichat
    gh copilot explain $"($words | str join ' ')"
}


# ^git cd to root (bare or worktree)
def --env git-root [] {
    if ((git worktree bare-path) == null) {
        cd (git rev-parse --show-toplevel)
    } else {
        cd (git worktree bare-path)
    }
}
# cd to git root (bare or worktree)
export alias cdroot = git-root

export def "python multi-fix" [] {
    ruff check --fix
    black .
    pyright .
}


export module "my" {

    export def "machine" [] { nvim ~/src/dotfiles/config/nushell/src/os-this-machine.nu }

    export def "nvim config" [] { nvim ~/src/kickstart.nvim/init.lua }

    export def "espanso config" [] {
        if $nu.os-info.name == "windows" {
            nvim $"($env.APPDATA)/espanso/default.yml"
        } else {
            error make {msg: "espanso config missing?"}
        }
    }

    export def "broot config" [] {
        if $nu.os-info.name == "windows" {
            nvim $"($env.APPDATA)/dystroy/broot/config/conf.hjson" $"($env.APPDATA)/dystroy/broot/config/verbs.hjson"
        } else {
            nvim "~/.config/broot/config/conf.hjson" "~/.config/broot/config/verbs.hjson"
        }
    }

    const repos = [~/src/dotfiles ~/src/kickstart.nvim]

    export def "repos status" [] {
        $repos | each {
            cd $in
            print $"(ansi pb)($in)(ansi reset)"
            ^git status
        }
    }

    export def "repos push" [] {
        $repos | each {
            cd $in
            print $"(ansi pb)($in)(ansi reset)"
            ^git push --force-with-lease
        }
    }

    export def "repos pull" [] {
        $repos | each {
            cd $in
            print $"(ansi pb)($in)(ansi reset)"
            ^git pull
        }
    }

}
