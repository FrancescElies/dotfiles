use broot-helpers.nu *
use my-functions.nu *
use reverse-eng.nu *
use utils.nu *
use symlinks.nu *


const max_bin = if $nu.os-info.name == "windows" {
    "C:/Program Files/Cycling '74/Max 9/Max.exe"
} else if $nu.os-info.name == "macos" {
    "/Applications/Max.app/Contents/MacOS/Max"
} else {
    error make {msg: not-implemented }
}

const max_resources_pkgs = if $nu.os-info.name == "windows" {
    "C:/Program Files/Cycling '74/Max 9/resources/packages"
} else if $nu.os-info.name == "macos" {
    error make {msg: not-implemented, }
} else {
    error make {msg: not-implemented, }
}

const max_examples = if $nu.os-info.name == "windows" {
    "C:/Program Files/Cycling '74/Max 9/examples"
} else if $nu.os-info.name == "macos" {
    error make {msg: not-implemented, }
} else {
    error make {msg: not-implemented, }
}

const max_searchpaths = if $nu.os-info.name == "windows" {
    "~/AppData/Roaming/Cycling '74/Max 9/Settings/maxsearchpaths.txt"
} else if $nu.os-info.name == "macos" {
    error make {msg: not-implemented, }
} else {
    error make {msg: not-implemented, }
}

def "nu-complete maxpats" [] { {
    options: { completion_algorithm: fuzzy, case_sensitive: false, positional: false, sort: true, },
    completions: (fd maxpat | lines)
} }

# Run cdb (x64) on a .dmp
#   • default  : stream output to the screen only
#   • --log/-l : additionally write <dump>.log next to the .dmp
def "Max dump" [
    dmpfile: string          # positional argument: the .dmp
    --log(-l)                # optional flag       : save a .log
] {
    let cdb = 'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe'
    if not ($cdb | path exists) {
        error make {msg: 'cdb.exe not found – run  winget install "windows driver kit"'}
    }

    let dump_path = ($dmpfile | path expand)
    if not ($dump_path | path exists) {
        error make {msg: $"dump file ($dump_path) does not exist"}
    }

    if $log {
        let parsed   = ($dump_path | path parse)
        let log_file = ($parsed.parent) | path join $"($parsed.stem).log"

        run-external $cdb "-z" $dump_path "-c" '!analyze -v; !pe; q' "-logo" $log_file
        print $"saved debugger log → ($log_file)"
    } else {
        run-external $cdb "-z" $dump_path "-c" '!analyze -v; !pe; q'
    }
}

def "nu-complete maxloglevel" [] { {
    options: { completion_algorithm: fuzzy, case_sensitive: false, positional: false, sort: true, },
    completions: ([info debug trace])
} }


# Cycling '74 Max cli wrap
export def "Max start" [
    maxpat?: path@"nu-complete maxpats"
    --log(-l): string@"nu-complete maxloglevel"
] {
    mut args = []
    if $log != null { $args = ($args | append $'--log=($log)') }
    Max preferences set no-crashrecovery
    Max preferences set node-logging
    Max preferences set logtosystemconsole
    if ($maxpat | is-empty) {
        print $"(ansi pb)> ($max_bin)(ansi reset)"
        run-external $max_bin ...$args
    } else {
        print $"(ansi pb)> ($max_bin) ($maxpat | path expand)(ansi reset)"
        run-external $max_bin ...$args ($maxpat | path expand)
    }
}

def "nu-complete my-maxpats" [] { {
    options: { completion_algorithm: fuzzy, case_sensitive: false, positional: false, sort: true, },
    completions: (fd maxpat /s/my-maxpats | lines)
} }

# Cycling '74 Max cli wrap
export def "Max start my" [maxpat: path@"nu-complete my-maxpats"] {
    cd /s/my-maxpats
    Max preferences set no-crashrecovery
    Max preferences set node-logging
    Max preferences set logtosystemconsole
    print $"(ansi pb)> ($max_bin) ($maxpat | path expand)(ansi reset)"
    run-external $max_bin ( $maxpat | path expand )
}

export def "Max fzf-examples" [] {
    cd $max_examples
    Max start (fd . | fzf)
}

def "nu-complete maxhelp" [] { cd $max_resources_pkgs; ls | get name}
export def "Max help" [folder: path@"nu-complete maxhelp"] {
    let dir = ($max_resources_pkgs | path join $folder)
    cd $dir
    Max start (fd maxhelp | fzf)
}


# sets Max Audio Status
export def "Max set audio-status" [] {
    let path = ("~/AppData/Roaming/Cycling '74/Max 9/Settings/admme@.txt" | path expand)
    print "Before"
    bat --paging never $path

    let contents = [
        'max v2;'
        'dsp prefsr 44100;'
        'dsp prefiovs 512;'
        'dsp prefsigvs 256;'
        'dsp takeover 0;'
        'dsp cpulimit 0;'
        'dsp optimize 1;'
        '#AD version 20030520;'
        '#AD mmeinputdevicepref "Microphone Array (Realtek(R) Au";'
        '#AD mmeoutputdevicepref "Lautsprecher (Realtek(R) Audio)";'
        '#AD threadpriority 3;'
        '#AD mme_latency 7;'
    ]
    $contents | to text | save -f $path
    print "Now"
    bat --paging never $path
}

const maxpreferences = ("~/AppData/Roaming/Cycling '74/Max 9/Settings/maxpreferences.maxpref" | path expand)

# opens maxinterface.json
export def "Max edit interface" [] { nvim "C:/Program Files/Cycling '74/Max 9/resources/interfaces/maxinterface.json" }
export def "Max edit maxpreferences" [] { nvim $maxpreferences }

export def --env "Max goto settings" [] { cd "~/AppData/Roaming/Cycling '74/Max 9/Settings"; lsg }
export def --env "Max goto installation-dir" [] { cd "C:/Program Files/Cycling '74/Max 9"; lsg }
export def --env "Max goto resources" [] { cd "C:/Program Files/Cycling '74/Max 9/resources"; lsg }
export def --env "Max goto appdata-roaming" [] { cd "~/AppData/Roaming/Cycling '74"; lsg }
export def --env "Max goto packages" [] { cd "~/Documents/Max 9/Packages"; lsg }
export def --env "Max goto sdk-examples" [] { cd "~/src/oss/max-sdk/source"; lsg }

# goto  crash dumps are stored
export def --env "Max list dumps" [] { ls `~/AppData/Roaming/Cycling '74/Logs/` | sort-by modified | get name }
# goto where logsk are stored
export def --env "Max list logs" [] { ls `~/AppData/Roaming/Cycling '74/Max 9/Logs/` | sort-by modified | get name }

# opens Max's api
export def "Max goto header-files" [] {
    let sdk_base = "~/src/oss/max-sdk/source/max-sdk-base"
    if not ($sdk_base | path exists) { mkdircd ~/src/oss; git clone https://github.com/Cycling74/max-sdk }
    cd ( $sdk_base | path join "c74support/max-includes" )
    lsg
}


export def "Max download-installers" [] {
    let dir = '/s/installers-exe'
    mkdir $dir
    cd $dir
    if not ("Max862_240319.zip" | path exists) { wget https://downloads.cdn.cycling74.com/max8/Max862_240319.zip }
    if not ("Max833_221006.zip" | path exists) { wget https://downloads.cdn.cycling74.com/max8/Max833_221006.zip }

}

export def "Max preferences set no-crashrecovery" [] {
    open $maxpreferences | from json
    | upsert preferences.crashrecovery Never
    | to json | save -f $maxpreferences
}

export def "Max preferences set logtosystemconsole" [] {
    open $maxpreferences | from json
    | upsert preferences.logtosystemconsole 1
    | to json | save -f $maxpreferences
}

export def "Max preferences set node-logging" [] {
    const logname = "node-for-max-log.txt"
    let logfolder = pwd
    print $"(ansi pb)> tspin ($logname)(ansi reset)"
    open $maxpreferences | from json
    | upsert preferences.n4m_debug_log_name $logname
    | upsert preferences.n4m_debug_log_enabled 1
    | upsert preferences.n4m_debug_log_folder $logfolder
    | to json | save -f $maxpreferences
    return ($logfolder | path join $logname)
}

# greps for something max related in all known locations where something interesting might be found
export def "Max rg" [pattern: string] {
    let locations = [
        ("~/src/oss/max-sdk" | path expand),
        ("C:/Program Files/Cycling '74" | path expand),
        ("~/AppData/Roaming/Cycling '74"| path expand),
    ]
    rg $pattern ...$locations
}

# ripgrep Max stuff
export alias "rg-max" = rg --type-add 'max:*.{maxhelp,maxpat,json}' -t max

export def "Max list loaded-mxe64" [] {
    (frida -p (ps | where name =~ Max | get 0.pid)
        --eval 'Process.enumerateModules()' -q
        | from json
        | where ($it.name | str ends-with mxe64))
}

export def "Max list available-objects" [] {
    let alias = (
        ls `~/Documents/Max 9/Packages/*/init/*txt` | get name | each { |file|
            ( open $file | parse "max objectfile {name} {obj};"
                | insert max-package { $""}
                | insert description { $"alias of $($in.obj) by ($file | path basename)"} )
        }
    ) | flatten
    let objects_without_alias = (
        fd --follow -HI mxe64 ("~/Documents/Max 9/Packages" | path expand) | lines | path parse | get stem
        | each {
            if not ($in in $alias.obj) { $in } } | wrap name | insert description { null }
    )
    $alias | select name description | append $objects_without_alias
}

export def "Max list node-procs" [] {
    ps --long | where name =~ node | where command =~ Max | select pid name cwd command
}

export def "Max use stable" [] { symlink --force `/Program Files/Cycling '74/Max9-stable/` `/Program Files/Cycling '74/Max 9` }
export def "Max use 910" [] { symlink --force `/Program Files/Cycling '74/Max 910/` `/Program Files/Cycling '74/Max 9` }
export def "Max use 911" [] { symlink --force `/Program Files/Cycling '74/Max 911/` `/Program Files/Cycling '74/Max 9` }
