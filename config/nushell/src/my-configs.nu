export module "my config" {

    export def "edit this-machine" [] { nvim ~/src/dotfiles/config/nushell/src/os-this-machine.nu }

    export def "edit weztern" [] { nvim ~/src/wezterm-config/wezterm.lua }

    export def "edit nvim" [] { nvim ~/src/kickstart.nvim/init.lua }

    export def "edit espanso" [] {
        if $nu.os-info.name == "windows" {
            nvim $"($env.APPDATA)/espanso/default.yml"
        } else {
            error make {msg: "espanso config missing?"}
        }
    }

    export def "edit broot" [] {
        if $nu.os-info.name == "windows" {
            nvim $"($env.APPDATA)/dystroy/broot/config/conf.hjson" $"($env.APPDATA)/dystroy/broot/config/verbs.hjson"
        } else {
            nvim "~/.config/broot/config/conf.hjson" "~/.config/broot/config/verbs.hjson"
        }
    }

    const config_repos = [~/src/dotfiles/config/nushell ~/src/kickstart.nvim ~/src/wezterm-config]

    export def "status-all" [] {
        $config_repos | each {
            cd $in
            print $"(ansi pb)($in)(ansi reset)"
            ^git status
        }
    }

    export def "push-all" [] {
        $config_repos | each {
            cd $in
            print $"(ansi pb)($in)(ansi reset)"
            ^git push --force-with-lease
        }
    }

    export def "pull-all" [] {
        $config_repos | each {
            cd $in
            print $"(ansi pb)($in)(ansi reset)"
            ^git pull
        }
    }

}
