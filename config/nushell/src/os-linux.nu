export def --env "ssh-agent start" [] {
    ^ssh-agent -c
        | lines
        | first 2
        | parse "setenv {name} {value};"
        | transpose -r
        | into record
        | load-env
}

export def "my rqbit" [] { start http://intel-pc:3030/web }
export def "my prowlarr" [] { start http://intel-pc:9696/ }
export def "my jellyfin" [] { start http://intel-pc:8096 }
export def "my torrents" [] {
    my rqbit
    my prowlarr
    my jellyfin
}
