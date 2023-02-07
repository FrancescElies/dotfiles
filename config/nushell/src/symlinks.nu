# Create a symlink
export def symlink [
    existing: path   # The existing file
    new_link_name: path  # The name of the symlink
    --force(-f)     # if target exists moves it to
] {
    let existing = ($existing | path expand --strict | path split | path join)
    let $new_link_name = ($new_link_name | path expand --no-symlink | path split | path join)
    print $"(ansi purple_bold)Creating symlink(ansi reset) ($existing) --> ($new_link_name)"


    # create parent folder if it doesn't exist
    mkdir ($new_link_name | path dirname)

    if ($force and ($new_link_name | path exists)) {
       rm --recursive $new_link_name
    }

    if $nu.os-info.family == 'windows' {
        if ($existing | path type) == 'dir' {
            print $"dir link created ($new_link_name)"
            mklink /D $new_link_name $existing
        } else {
            print $"file link created ($new_link_name)"
            mklink $new_link_name $existing
        }
    } else {
        print $"link created ($new_link_name)"
        ln -s $existing $new_link_name | ignore
    }
}
