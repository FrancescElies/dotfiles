# Shared runtime helpers for config.nu. Requires Nushell 0.117 or newer.

def trust-file [] {
    $env.DOTFILES_PROJECT_TRUST_FILE? | default ($nu.data-dir | path join trusted-projects.nuon) | path expand
}

def canonical-project [directory: path] {
    let directory = $directory | path expand --strict
    if ($directory | path type) != dir {
        error make {msg: $"Not a directory: ($directory)"}
    }
    $directory
}

def trusted-directories [] {
    let file = trust-file
    if not ($file | path exists) { return [] }
    let directories = open $file
    if ($directories | describe) != 'list<string>' and ($directories | describe) != 'list<any>' {
        error make {msg: $"Invalid project trust list: ($file)"}
    }
    if not ($directories | all {|directory| ($directory | describe) == string }) {
        error make {msg: $"Invalid project trust list: ($file)"}
    }
    $directories
}

def save-trusted-directories [directories: list<string>] {
    let file = trust-file
    mkdir ($file | path dirname)
    $directories | uniq | to nuon | save --force $file
}

# Trust only this exact directory, not its children. Review local code first.
export def "project trust" [directory: path = '.'] {
    let directory = canonical-project $directory
    save-trusted-directories (trusted-directories | append $directory)
    print $"Trusted ($directory). Re-enter it to activate project hooks."
}

export def "project untrust" [directory: path = '.'] {
    let directory = $directory | path expand
    save-trusted-directories (trusted-directories | where {|item| $item != $directory })
}

export def "project trusted" [] { trusted-directories }

export def "project is-trusted" [directory: path] {
    # Malformed/unreadable trust files and missing directories must fail closed.
    try { (canonical-project $directory) in (trusted-directories) } catch { false }
}

# Remove only paths we added, preserving existing PATH entries and their order.
export def --env "project sync-path" [directory: path] {
    # Serialize bookkeeping so it survives inheritance by a child Nu process.
    let previous = try {
        $env.DOTFILES_PROJECT_PATH_ADDITIONS? | default '[]' | from nuon
    } catch { [] }
    let base = $env.PATH | where {|entry| $entry not-in $previous }
    let candidates = if (project is-trusted $directory) and ($directory | path join Cargo.lock | path exists) {
        ['target/debug' 'target/debug/examples' 'target/release' 'target/release/examples']
        | each {|suffix| $directory | path join $suffix | path expand }
        | uniq
    } else { [] }
    let additions = $candidates | where {|entry| $entry not-in $base }
    $env.PATH = $base | append $additions
    $env.DOTFILES_PROJECT_PATH_ADDITIONS = $additions | to nuon
}

# Raw strings preserve backslashes and control characters without interpolation.
# Grow the delimiter until the value cannot close the literal prematurely.
export def "nu quote-path" [value: string]: nothing -> string {
    mut hashes = '#'
    while ($value | str contains $"'($hashes)") { $hashes += '#' }
    $"r($hashes)'($value)'($hashes)"
}

# Completion words retain source quotes in Nu 0.117. Decode string literals
# without evaluating variables, substitutions, or arbitrary shell expressions.
export def "nu completion-word" [word: string]: nothing -> string {
    try {
        let decoded = $word | from nuon
        if ($decoded | describe) == string { $decoded } else { $word }
    } catch { $word }
}

# Empty selections and cancellation leave the working directory untouched.
export def --env "cd selected" [selection: any] {
    if ($selection | is-not-empty) { cd $selection }
}

export def "pick file insert" [] {
    let selection = try {
        ^fd --type file --hidden --exclude .git --print0
        | ^fzf --read0 --print0 --preview 'bat --color=always --style=full --line-range=:500 {}'
    } catch { null }
    if ($selection | is-not-empty) {
        commandline edit --insert (nu quote-path ($selection | str replace --regex '\x00$' ''))
    }
}

export def --env "pick directory" [] {
    let selection = try {
        ^fd --type dir --hidden --exclude .git --print0
        | split row "\u{0}"
        | where {|directory| $directory != '' }
        | input list --fuzzy
    } catch { null }
    cd selected $selection
}

export def "pick module" [] {
    let modules = $env.NU_LIB_DIRS
        | each {|directory| try { glob ($directory | path expand | path join '*.nu') --no-dir } catch { [] } }
        | flatten
        | uniq
    if ($modules | is-empty) { return }
    let selection = try { $modules | input list --fuzzy 'Choose a module to load:' } catch { null }
    if ($selection | is-not-empty) {
        commandline edit --replace $"use (nu quote-path $selection) *"
        commandline set-cursor --end
    }
}
