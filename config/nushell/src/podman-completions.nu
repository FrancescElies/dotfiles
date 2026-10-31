def "nu-complete jellyfin actions" [] { ["run" "stop" "logs"] }
export def podman-jellyfin [action: string@'nu-complete jellyfin actions'] {
    match $action {
        "run" => {(
          ^podman run -d --name jellyfin --label "io.containers.autoupdate=registry"
              --publish 8096:8096/tcp --publish 7359:7359/udp
              --device /dev/dri/ --user $"(id -u):(id -g)" --userns keep-id --replace
              --volume jellyfin-cache:/cache:Z --volume jellyfin-config:/config:Z
              --mount $"type=bind,source=($env.HOME)/Music,destination=/media/Music,ro=true,relabel=private"
              --mount $"type=bind,source=($env.HOME)/Videos,destination=/media/Videos,ro=true,relabel=private"
              docker.io/jellyfin/jellyfin:latest
        )}
        "stop" => { ^podman stop jellyfin }
        "logs" => { ^podman logs -f jellyfin }
        _ => { error make {msg: "usage: jellyfin [run|stop|logs]"} }
    }
}

export def --wrapped podman-pi [...args] {
    # searxng must be running on searchnet as "searxng"
    (podman run --rm -it
        --network searchnet -e SEARXNG_BASE_URL=http://searxng:8080
        -e PI_PROVIDER -e PI_MODEL -e PI_REASONING_LEVEL -e PI_TELEMETRY -e PI_CODING_AGENT
        -v $"(pwd):/workspace" -v $"('~/.pi/agent' | path expand):/root/.pi/agent"
        ...$args localhost/pi)
}

export def --wrapped podman-r2 [...args] {
    podman run --rm -it -v $"(pwd):/workspace" -v $"('~/src/dotfiles/config/.radare2rc' | path expand):/root/.radare2rc" ...$args localhost/r2
}

export def --wrapped podman-searxng [...args] {
    if (podman network exists searchnet | complete).exit_code != 0 { podman network create searchnet }
    podman rm -f searxng | complete | ignore
    podman run -d --name searxng --network searchnet -p 127.0.0.1:8080:8080 ...$args localhost/searxng
}

def "nu-complete sandbox rebuild folders" [] {
    (ls ("~/src/dotfiles/bin/containers" | path expand) | where type == "dir"
    | where { ($in.name | path join "Containerfile" | path exists) }
    | each {$in.name|path basename })  ++ ["all"]
}
export def "podman rebuild-sandbox" [folder: string@'nu-complete sandbox rebuild folders'] {
    let base = ("~/src/dotfiles/bin/containers" | path expand)
    if $folder == "all" {
        let dirs = (ls $base | where type == "dir"
            | where { ($in.name | path join "Containerfile" | path exists) })
        for dir in $dirs {
            let name = ($dir.name | path basename)
            print $"(ansi pb)building podman localhost/($name)(ansi reset)"
            cd $dir.name
            ^podman build -t $"localhost/($name)" .
        }
    } else {
        do { cd ($base | path join $folder); podman build -t $"localhost/($folder)" . }
    }
}
