def wt-list [] {
    git worktree list --porcelain | split row "\n\n" | where {|b| ($b | str trim) != "" } | each {|b|
        let l = $b | lines
        let path = $l.0 | str replace "worktree " ""
        let branch = ($l | where {|x| $x starts-with "branch " }).0? | default "(detached)" | str replace "branch refs/heads/" ""
        let prunable = ($l | where {|x| $x starts-with "prunable" } | is-not-empty)
        let ok = ($path | path exists)
        let dirty = if $ok { (git -C $path status --porcelain e> (if $nu.os-info.name == "windows" { "NUL" } else { "/dev/null" }) | lines | length) } else { null }
        let merged = if $ok and $branch != "(detached)" { (git branch --merged master --format '%(refname:short)' | lines) | any {|x| $x == $branch } } else { false }
        { name: ($path | path basename), branch: $branch, dirty: $dirty, merged: $merged, prunable: $prunable, path: $path }
    }
}

# Table of worktrees
export def wt [] { wt-list | reject path }

# Fuzzy-pick a worktree and open it in a wezterm workspace named after it
export def "wt jump" [] {
    let pick = wt-list | where {|r| not $r.prunable } | input list --fuzzy --display name "Worktree:"
    if $pick == null { return }
    # wezterm.lua (user-var-changed JUMP_WORKSPACE) does the actual switch
    let v = $"($pick.name)|($pick.path)" | encode base64
    print -n $"(char -u "1b")]1337;SetUserVar=JUMP_WORKSPACE=($v)(char bel)"
}

# Remove prunable worktrees and clean (merged, no changes) ones, after confirmation
export def "wt clean" [] {
    let rows = wt-list | where {|r| $r.name != "main" and ($r.prunable or ($r.merged and $r.dirty == 0)) }
    if ($rows | is-empty) { print "Nothing to clean"; return }
    print ($rows | select name branch prunable merged)
    if (["no" "yes"] | input list "Remove these?") != "yes" { return }
    for r in ($rows | where not prunable) { git worktree remove $r.path }
    git worktree prune
}

# Draft a commit message from the staged diff with pi, edit it in nvim, then commit
export def gc [] {
    let diff = git diff --staged
    if ($diff | is-empty) { error make { msg: "Nothing staged" } }
    let f = (git rev-parse --git-path COMMIT_EDITMSG | str trim)
    $diff | pi --model gpt-6-luna -p "Write a concise git commit message (subject line <=72 chars, optional short body) for this staged diff. Output only the message." | save -f $f
    nvim $f
    if ((open $f | str trim | is-empty)) { print "Empty message, aborted"; return }
    git commit -F $f
}

# Rewrite commit hours to 6pm-1am, only my commits, skip already-in-ballpark
export alias rewrite-git-hours = uv run --with git-filter-repo python ~/src/dotfiles/bin/rewrite-git-hours.py
