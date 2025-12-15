# https://www.youtube.com/watch?v=aolI_Rz0ZqY
# Apply some useful defaults
# ^gmy-defaults
#
# Give me all my pull requests as local refs
# ^git config remote.origin.fetch '+refs/pull/*:refs/remotes/origin/pull/*'
#
# Conditional ~/.gitconfig
#
# [includelf "gitdir:~/projects/work/"]
#   path = /s/.gitconfig
# [includelf "gitdir:~/src/oss/"]
#   path = ~/projects/oss/.gitconfig
#
# Accidentally cloned http repo version?
# [url "git@github.com:"]
#   insteadOf = "https://github.com/"
# ^git maintenance start

# apply my defaults
export def "git set my-defaults" [] {
  # https://jvns.ca/blog/2024/02/16/popular-git-config-options/#help-autocorrect-10
  ^git config --global push.autosetupremote true
  ^git config --global init.defaultBranch main
  ^git config --global pull.rebase true
  ^git config --global merge.conflictstyle zdiff3
  ^git config --global rebase.autosquash true
  ^git config --global push.default current
  ^git config --global help.autocorrect 10
  ^git config --global interactive.diffFilter delta --color-only
  ^git config --global diff.algorithm histogram
  ^git config --global branch.sort -committerdate
  ^git config --global fetch.prune true
  ^git config --global log.date iso
  ^git config --global rebase.missingCommitsCheck error
  ^git config --global rebase.updateRefs true

  # Avoid data corruption
  ^git config --global transfer.fsckobjects true
  ^git config --global fetch.fsckobjects true
  ^git config --global receive.fsckObjects true

  # REuse REordered REsolution, tells ^git to remember conflicts so if it sees them again he won't ask about it.
  ^git config --global rerere.enabled true
  ^git config --global branch.sort -committerdate
  # ^git config gpg.format ssh
  # ^git config user.signingkey ~/.ssh/id_ed25519

  # Big repository stuff
  #
  # ^git clone filters:
  # ^git clone --fitter=blob:none
  # ^git clone --fitter=tree:zero
  #
  # See multipack indexes, reachability bitmaps and geometric repacking
  # https://github.blog/2021-04-29-scaling-monorepo-maintenance
  # ^git maintenance start will also write the commit-graph
  ^git config --global fetch.writeCommitGraph true
  # file system monitory
  ^git config --global core.untrackedcache true
  ^git config --global core.fsmonitor true
}

# gi diff with external difftool
export def --wrapped "git difft" [...rest] { with-env {GIT_EXTERNAL_DIFF: difft} { ^git diff ...$rest } }

# list git branches sorted by date
export def "gbranches" [first: int = 5] { ^git branch --sort=-committerdate | lines | first $first }

export alias gd = ^git difft
export alias gds = ^git difft --staged
# Yield remote branches like `origin/main`, `upstream/feature-a`
def "nu-complete git remote branches with prefix" [] {
    {
        options: { completion_algorithm: fuzzy, case_sensitive: false, positional: false, sort: true, },
        completions: ( ^git branch --no-color -r | lines | parse -r '^\*?(\s*|\s*\S* -> )(?P<branch>\S*$)' | get branch | uniq )
    }
}
# gd-merge-base
export def gdmb [
  rev1: string@"nu-complete git remote branches with prefix"
  rev2: string@"nu-complete git remote branches with prefix"
] { ^git diff $rev1 (git merge-base $rev1 $rev2) }

# git search: useful when you’re looking for an exact block of code (like a struct), and want to know the history of that block since it first came into being
export alias "git log-search" = ^git log -p -S

# better blame: ^git blame ignore white-space, deleted lines moved/copied, or any commit
export alias "git bblame" = ^git blame -w -C -C -C

# git log pretty
export alias "git log-pretty" = ^git log --graph --pretty=format:'%C(auto)%h -%d %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
export alias "git log-pretty-merges" = git log-pretty --merges --first-parent

export alias uncommit = ^git reset --soft HEAD~1
export alias unadd = ^git reset HEAD

export def push [--upstream(-u): string = "origin", --force-with-lease(-f), --force(-F)] {
  mut args = []
  if $force_with_lease != null { $args = ($args | append $'--force-with-lease') }
  if $force != null { $args = ($args | append $'--force') }
  ^git push ...$args --set-upstream $upstream (git rev-parse --abbrev-ref HEAD)
}
export def pull [--upstream(-u): string = "origin"] { ^git pull --set-upstream $upstream (git rev-parse --abbrev-ref HEAD) }

# git rebase merge base
export def merge-base [ rev: string@"nu-complete git remote branches with prefix" ] { git merge-base (git rev-parse --abbrev-ref HEAD) $rev }


# Repack repositories in current folder
# repacker: repack a repo the way Linus recommends.
#
# This command takes a long time to run, perhaps even overnight.
#
# It does the equivalent of "git gc --aggressive"
# but done *properly*,  which is to do something like:
#
#     ^git repack -a -d --depth=250 --window=250
#
# The depth setting is about how deep the delta chains can be;
# make them longer for old history - it's worth the space overhead.
#
# The window setting is about how big an object window we want
# each delta candidate to scan.
#
# And here, you might well want to add the "-f" flag (which is
# the "drop all old deltas", since you now are actually trying
# to make sure that this one actually finds good candidates.
#
# And then it's going to take forever and a day (ie a "do it overnight"
# thing). But the end result is that everybody downstream from that
# repository will get much better packs, without having to spend any effort
# on it themselves.
#
# http://metalinguist.wordpress.com/2007/12/06/the-woes-of-git-gc-aggressive-and-how-git-deltas-work/
#
# We also add the --window-memory limit of 1 gig, which helps protect
# us from a window that has very large objects such as binary blobs.
#
export def "git repack-repos" [
  path: path = .
  --prune
] {
    ls $path | where type == dir | each { |folder|
        print $"Repacking ($folder.name)"
        cd $folder.name
        if $prune {
          ^git prune --expire=now
          ^git reflog expire --expire-unreachable=now --rewrite --all
        }
        ^git repack -a -d -f --depth=300 --window=300 --window-memory=1g
    }
}
export alias grepack = git repack-repos

# Delete ^git merged branches (local and remote)
export def "git gone" [remote: string = 'origin'] {
    let branches = git branch --merged | lines | where ($it != "* master" and $it != "* main") | str trim
    $branches | each {git branch -D ($in ) }

    if (input $"(ansi pb)Do you want to delete remote branches too [y/n](ansi reset)?" | str downcase) == "y" {
        $branches | each {git push $remote --delete $in }
    }
}

#  View ^git committer activity as a histogram
export def "git activity" [
  path: path = .  # e.g. '*.rs', ./src ...
  --since: string = '1 year ago'
] {
  ^git log --since $'"($since)"' --pretty=%h»¦«%aN»¦«%s»¦«%aD  -- $path
  | lines
  | split column "»¦«" sha1 committer_name desc merged_at
  | histogram committer_name merger
  | sort-by merger
  | reverse
}


# https://stackoverflow.com/questions/46704572/git-error-encountered-7-files-that-should-have-been-pointers-but-werent
export def "git fix-everything" [] { ^git lfs migrate import --fixup --everything }

# This "migrates" files to ^git lfs which should be in lfs as per .gitattributes,
# but aren't at the moment (which is the reason for your error message).
#
# --no-rewrite prevents ^git from applying this to older commits, it creates a single new commit instead.
#
# Use -m "commitmessage" to set a commitmessage for that commit.
# https://stackoverflow.com/questions/46704572/git-error-encountered-7-files-that-should-have-been-pointers-but-werent
export def "git lfs-fix" [...paths: path] { ^git lfs migrate import --no-rewrite ...$paths }

export def "nu-complete semmantic-message" [] {
    # https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716
    [
        [value    description];
        [build    "new feature for the user, not a new feature for build script"]
        [chore    "updating grunt tasks etc; no production code change"]
        [ci       "ci"]
        [docs     "changes to the documentation"]
        [feat     "new feature for the user, not a new feature for build script"]
        [fix      "bug fix for the user, not a fix to a build script"]
        [perf     "performance"]
        [refactor "refactoring production code, eg. renaming a variable"]
        [style    "formatting, missing semi colons, etc; no production code change"]
        [test     "adding missing tests, refactoring tests; no production code change"]
    ]
}

# lightweight convention for commit messages
# https://www.conventionalcommits.org/en/v1.0.0/
export def --wrapped "commit" [
    type: string@"nu-complete semmantic-message"
    title: string
    --scope(-s): string     # adds contextual(information)
    --breaking-changes(-b)  # adds ! to commit title
    ...rest
] {
    let scope = if ($scope | is-empty) { "" } else { $"\(($scope)\)" }
    let breaking_change = if $breaking_changes { "!" } else { "" }
    ^git commit -m $"($type)($scope)($breaking_change): ($title)" ...$rest
}

# Creates a table listing the branches of a git repository and the day of the last commit
export def "git branch-ages" [] {
    git branch |
    lines |
    str substring 2.. |
    wrap name |
    insert last_commit {
        get name |
        each {
            git show $in --no-patch --format=%as | into datetime
        }
    } |
    sort-by last_commit
}


#
# worktrees
#

# git worktree list as table
export def --wrapped "git worktree list" [...rest] {
  ^git worktree list ...$rest | lines | parse --regex `(?P<path>.+?) +(?P<commit>\w+) \[(?P<branch>.+)\]`
}

def "nu-complete gw-paths" [] { git worktree listt | get path }

# git worktree change directory
export def --env "git worktree cd" [
  path?: string@"nu-complete gw-paths"  # branch to create or checkout
] {
  cd $path
}

# git worktree remove
export def --env "git worktree remove-with-force" [path: string@"nu-complete gw-paths"] {
  git clean -fdx; git worktree remove --force $path
}

export def "git worktree bare-path" [] {
  ^git worktree list | parse --regex `(?P<path>.+?) +\(bare\)` | get 0?.path?
}



#
# Pull requests
#
export def "git pr diff" [
  --target-branch: string = "origin/master"  # pr's target branch (normally main, master, ...)
] {
  let this_branch = (git rev-parse --abbrev-ref HEAD)
  git diff $this_branch ( git merge-base $this_branch $target_branch )
}

# opens files modified by pr in nvim
export def "git pr files" [
  path: path = .
  --extension: string = ""  # ts, py, rs ... (no dot), default matches everything
  --target-branch: string = "origin/master"  # pr's target branch (normally main, master, ...)
] {
  let this_branch = (git rev-parse --abbrev-ref HEAD)
  let files = ( git diff --name-only $this_branch ( git merge-base $this_branch $target_branch ) | lines )
  if ($extension| is-empty) {
    $files
  } else {
    let filtered_files = ( $files | where { |x| ($x | path parse).extension == $extension} )
    $filtered_files
  }

}

# Opens current branch and target branch maxpats to comparison
export def "git pr review-maxpats" [
  --target-branch: string = "origin/master"  # pr's target branch (normally main, master, ...)
  --dry-run
] {
  print $"target branch: ($target_branch)"
  let prfiles = (pr files --extension maxpat --target-branch $target_branch)
  if $dry_run {
     print $prfiles
     return
  }
  let open_files = $prfiles | each { |x| (
    git show $"($target_branch):($x)"
    | save -f $"($x | path expand | path dirname)/tmp-target-($x | path basename)"
    ; start $x
    ; start $"($x | path expand | path dirname)/tmp-target-($x | path basename)"
    ; echo $x
  ) }

  let untracked_maxpats = (
    (git ls-files . --exclude-standard --others)
    | lines
    | path parse
    | where {|x| $x.extension == "maxpat"}
    | path join
  )
  print "untracked maxpats:"
  print $untracked_maxpats

  if (input "remove untracked maxpat files (y/n)?") == "y" {
    $untracked_maxpats | each { || rm $in }
  }
  print "Once done cleanup: rm tmp_*maxpat"

}

# Quickly add all files, commit changes, and push commits and all stashes to a new branch to prevent merge conflicts.
# Inspired by https://github.com/qw3rtman/git-fire
export def "git fire" [] {
    let initial_branch = git rev-parse --abbrev-ref HEAD
    let new_branch = $"fire/($initial_branch)-(date now | format date "%Y%m%d-%H%M%S")"
	git checkout -b "$(new_branch)"
	cd (git rev-parse --show-toplevel)
    git add -A
	git commit -m $"Fire! Branch (initial_branch)." --no-verify
    git remote | lines | each {
        |remote| try { git push --no-verify --set-upstream $remote $initial_branch }
    }

    let stash_complete = git rev-list -g stash | complete
    if $stash_complete.exit_code == 0 {
         git rev-list -g stash | lines | each {
            |sha| try { git push --no-verify origin $"($sha):refs/heads/($initial_branch)-stash-($sha)" }
        }
    }
}

export def "git standup" [--until: string, --since: string, --author: string] {
    mut args = []
    if $until != null { $args = ($args | append [--until $until]) }
    if $author != null { $args = ($args | append [--author (git config user.name)]) }
    if $since != null { $args = ($args | append [--since ($since)] ) }

    let format = "%Cred%h%Creset - %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"
    ( git --no-pager log --all
        --no-merges
        --abbrev-commit
        --oneline
        --pretty=$"format:'($format)'"
        --date='-relative'
        --color=always
        --stat
        ...$args
    )
}
