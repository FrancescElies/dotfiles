export def --env "ssh-agent start" [] {
    ^ssh-agent -c
        | lines
        | first 2
        | parse "setenv {name} {value};"
        | transpose -r
        | into record
        | load-env
}

export def "arr open bazarr" [] { start http://localhost:6767/ }
export def "arr open lidarr" [] { start http://localhost:8686/ }
export def "arr open radarr" [] { start http://localhost:7878/ }
export def "arr open readarr" [] { start http://localhost:8787/ }
export def "arr open qbittorrent" [] { start http://localhost:8080/ }
export def "arr open all" [] {
    my bazarr
    my lidarr
    my radarr
    my readarr
    my qbittorrent
}

export def "arr up" [] {
    podman compose -f /home/cesc/src/dotfiles/bin/containers/arr/docker-compose.yml up -d --build
}
export def "arr down" [] {
    podman compose -f /home/cesc/src/dotfiles/bin/containers/arr/docker-compose.yml down
}
export def "arr build" [] {
    podman compose -f /home/cesc/src/dotfiles/bin/containers/arr/docker-compose.yml build
}
