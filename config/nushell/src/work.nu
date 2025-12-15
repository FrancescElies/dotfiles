# stop git from trying to commit this file
# git update-index --assume-unchanged work.nu
#
# tell git to continue tracking this file as usual
# git update-index --no-assume-unchanged work.nu



export def maxmsp [maxpat: string = ""] {
    let max_exe = match $nu.os-info.name {
      "windows" => `C:/Program Files/Cycling '74/Max 8/Max.exe`
      "macos" => "/Applications/Max.app/Contents/MacOS/Max",
      _ => { error make {msg: "not implemented" } }
    }
    ^$max_exe ($maxpat | path expand)
}
