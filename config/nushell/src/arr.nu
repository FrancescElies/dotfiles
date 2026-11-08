const ARR_PORTS = { radarr: 7878, lidarr: 8686, prowlarr: 9696, qbittorrent: 8081 }
def "nu-complete arr services" [] { $ARR_PORTS | columns | append "all" }
# Open a service's web UI: `arr open radarr`, or `arr open all`
export def "arr open" [service: string@"nu-complete arr services"] {
    let known = ($ARR_PORTS | columns)
    let targets = if $service == "all" { $known } else { [$service] }
    for s in $targets {
        if $s not-in $known { error make { msg: $"unknown service: ($s)" } }
        start $"http://127.0.0.1:($ARR_PORTS | get $s)/"
    }
}


const ARR_DIR = ("~/src/dotfiles/bin/containers/arr" | path expand)

const COMPOSE_FILE =  $ARR_DIR | path join "compose.yml"
const ENV_FILE = $ARR_DIR | path join ".env"
const SEED_SCRIPT = $ARR_DIR | path join "seed-arr.py"

def --wrapped compose [...args: string] {
    ^podman compose -f $COMPOSE_FILE ...$args
}

def "nu-complete arr profile" [] { ["vpn" "novpn"] }

# read KEY from .env (inline "# comments" stripped)
def get-env [key: string, default?: string] {
    if not ($ENV_FILE | path exists) { return $default }
    let hit = (open --raw $ENV_FILE | lines | where {|l| $l | str starts-with $"($key)=" })
    if ($hit | is-empty) { return $default }
    $hit | last | split row "=" | skip 1 | str join "=" | split row " #" | first | str trim
}

# set KEY=VALUE in .env (replace or append)
def set-env [key: string, value: string] {
    let lines = (open --raw ($ENV_FILE) | lines)
    let new = if ($lines | any {|l| $l | str starts-with $"($key)=" }) {
        $lines | each {|l| if ($l | str starts-with $"($key)=") { $"($key)=($value)" } else { $l } }
    } else {
        $lines | append $"($key)=($value)"
    }
    $"($new | str join "\n")\n" | save -f ($ENV_FILE)
}

# Prepare the stack: create .env, choose vpn/novpn, create folders, pull images
export def "arr build" [
    profile?: string@"nu-complete arr profile"   # vpn | novpn (asked interactively if omitted)
] {
    if not ($ENV_FILE | path exists) {
        print "No .env yet, generating one..."
        ^python3 $SEED_SCRIPT | complete | get stderr | print
    }

    let new = if $profile != null { $profile } else { ["vpn" "novpn"] | input list "VPN profile:" }
    if $new == null { return }
    if $new not-in ["vpn" "novpn"] { error make { msg: "profile must be vpn or novpn" } }

    let old = (get-env COMPOSE_PROFILES "vpn")
    if $old != $new {
        print $"Profile ($old) -> ($new): stopping running containers first"
        compose --profile "*" down
    }
    set-env COMPOSE_PROFILES $new

    if $new == "vpn" and ((get-env WIREGUARD_PRIVATE_KEY "") | is-empty) {
        print $"(ansi yellow)TODO: fill WIREGUARD_PRIVATE_KEY and WIREGUARD_ADDRESSES in ($ENV_FILE)(ansi reset)"
    }

    let root = (get-env ARR_ROOT "/media/cesc/data/arr")
    for d in [
        config/lidarr config/radarr config/prowlarr config/qbittorrent config/gluetun
        data/torrents/radarr data/torrents/lidarr data/media/movies data/media/music
    ] { mkdir ($root | path join $d) }
    ^podman unshare chown -R 1000:1000 ($root | path join "data")

    compose pull
    print $"Profile: ($new). Next: arr up --seed"
}

# Start the stack (profile comes from .env); --seed also configures the apps via API
export def "arr up" [--seed (-s)] {
    if not ($ENV_FILE | path exists) { error make { msg: "no .env: run `arr build` first" } }
    compose up -d
    if $seed { ^python3 $SEED_SCRIPT }
}

const ARR_CONTAINERS = [gluetun qbittorrent prowlarr radarr lidarr flaresolverr]

# Stop everything, whichever profile was running (-f: no grace period, remove leftovers)
export def "arr down" [--force (-f)] {
    if $force {
        do -i { compose --profile "*" down -t 0 }
        do -i { ^podman rm -f --ignore ...$ARR_CONTAINERS }
        do -i { ^podman pod rm -f --ignore pod_arr }
        do -i { ^podman network rm -f arr_arr }
    } else {
        compose --profile "*" down
    }
}

# Configure Radarr/Lidarr/Prowlarr/qBittorrent via API (idempotent)
export def "arr seed" [] {
    ^python3 $SEED_SCRIPT
}

# Show containers and health
export def "arr ps" [] {
    compose --profile "*" ps
}

def "nu-complete arr containers" [] { $ARR_CONTAINERS }
# Tail logs, e.g. `arr logs gluetun -f`
export def "arr logs" [
    service?: string@"nu-complete arr containers",
    --follow (-f),
    --tail (-n): int = 100,
] {
    let base = ["logs" "--tail" ($tail | into string)] | append (if $follow { ["-f"] } else { [] })
    if $service == null {
        compose ...$base                 # all services of the active profile
    } else {
        ^podman ...($base | append $service)
    }
}

# Restart one container or the whole stack
export def "arr restart" [service?: string@"nu-complete arr containers"] {
    if $service != null { ^podman restart $service } else { compose restart }
}

# Pull newer images and recreate changed containers
export def "arr update" [] {
    compose pull
    compose up -d
}

# Show the active profile
export def "arr profile" [] {
    get-env COMPOSE_PROFILES "vpn"
}

# Compare host IP with qBittorrent's (should differ in vpn mode)
export def "arr ip" [] {
    print $"host: (http get https://am.i.mullvad.net/connected | str trim)"
    print $"qbit: (^podman exec qbittorrent curl -s https://am.i.mullvad.net/connected | str trim)"
}
