# Run interactively so commandline complete uses the completion engine:
# nu --no-config-file --interactive config/nushell/tests/completions.nu
use std/assert
use ../src/git-completions.nu *
use ../src/just-completions.nu *
alias gco = git checkout

let original_directory = pwd
let temp = mktemp --directory
try {
    ^git init --quiet --initial-branch=main $temp
    cd $temp
    ^git config user.name 'Completion Test'
    ^git config user.email 'completion-test@example.invalid'
    'before' | save 'dirty file.txt'
    ^git add .
    ^git commit --quiet -m fixture
    'after' | save --force 'dirty file.txt'
    ^git remote add origin 'https://example.invalid/completion-test.git'
    ^git update-ref refs/remotes/origin/remote-branch HEAD

    let branches = 'git checkout ' | commandline complete --detailed | get value
    assert ('main' in $branches)
    let alias_branches = 'echo hi | gco ' | commandline complete --detailed | get value
    assert ('main' in $alias_branches)
    let files = 'git checkout main ' | commandline complete --detailed | get value
    assert ($files | any {|file| $file | str contains 'dirty file.txt' })
    let changed = 'git checkout -- ' | commandline complete --detailed | get value
    assert ($changed | any {|file| $file | str contains 'dirty file.txt' })
    let refs = 'git push origin ' | commandline complete --detailed | get value
    assert (':remote-branch' in $refs)
    let quoted_refs = 'git push "origin" ' | commandline complete --detailed | get value
    assert (':remote-branch' in $quoted_refs)

    "build name='default value':\n    @echo {{name}}\n\nneeds path:\n    @echo {{path}}\n" | save justfile
    let recipes = 'just ' | commandline complete --detailed | get value
    assert ('build' in $recipes)
    let arguments = 'just build ' | commandline complete --detailed | get value
    assert ($arguments | any {|value| $value | str contains 'default value' })
    let quoted_recipe = 'just --color always "build" ' | commandline complete --detailed | get value
    assert ($quoted_recipe | any {|value| $value | str contains 'default value' })
    let quoted = 'just build "already supplied" ' | commandline complete --input | get place.command
    assert equal ($quoted | length) 4
    assert equal ($quoted | get 2) '"already supplied"'
    assert equal ('just build "already supplied" ' | commandline complete --detailed | length) 0
    let required = 'just needs ' | commandline complete --detailed
    # Declining may yield built-in file suggestions; avoid malformed placeholders.
    assert ($required | all {|suggestion| ($suggestion.value | describe) == string })
    print 'completion tests passed'
} catch {|err|
    print --stderr $err.rendered
    cd $original_directory
    rm --recursive --force $temp
    error make {msg: $err.msg}
}
cd $original_directory
rm --recursive --force $temp
