export module ai {

    # Fail early with a clear message if an external tool is missing.
    def need [cmd: string] {
        if (which $cmd | is-empty) {
            error make {msg: $"required command not found: ($cmd)"}
        }
    }

    export def --wrapped pi [--sandboxed, --share: list<string>, ...args] {
        if $sandboxed {
            mut mounts = [-v $"(pwd):/workspace"]

            let agent_dir = $env.HOME | path join ".pi" "agent"
            if ($agent_dir | path exists) {
                $mounts = ($mounts | append [-v $"($agent_dir):/root/.pi/agent"])
            }

            let gitconfig = $env.HOME | path join ".gitconfig"
            if ($gitconfig | path exists) {
                $mounts = ($mounts | append [-v $"($gitconfig):/root/.gitconfig:ro"])
            }

            for p in ($share | default []) {
                let hp = $p | path expand
                let name = $hp | path basename
                $mounts = ($mounts | append [-v $"($hp):/shared/($name)"])
            }

            # keep files created in the workspace owned by the host user
            podman run --rm -it --user $"(id -u):(id -g)" ...$mounts localhost/pi ...$args
            return
        }
        match $nu.os-info.name {
            "windows" => {
                # WARN: calling pi (pi.cmd) directly breaks scrolling
                let cli_js = ([
                    ($env.FNM_DIR | path join "aliases" "default")
                    'node_modules\@earendil-works\pi-coding-agent\dist\cli.js'] | path join)
                if not ($cli_js | path exists) {
                    print 'missing pi:'
                    print '  fnm default v26'
                    print '  fnm use --install-if-missing --silent-if-unchanged v26'
                    print '  npm install -g --ignore-scripts @earendil-works/pi-coding-agent'
                    return
                }
                print $"running node ($cli_js)"
                fnm exec --using default -- node $cli_js ...$args
            }
            _ => {
                fnm exec --using default -- pi ...$args
            }
        }
    }

    export def --env pi-env [] { fnm use default }

    export def --env pi-docs [] {
        let root = match $nu.os-info.name {
            "windows" => (fnm exec --using default -- npm.cmd root -g)
            _ => (fnm exec --using default -- npm root -g)
        }
        let docs = $root | str trim | path join "@earendil-works/pi-coding-agent/docs"
        nvim -c $'cd ($docs)' -c 'e index.md'
    }

    const ai_slop = [
        '- Avoid ai slop'
        `- Avoid Filler openers: "In today's fast-paced world," "It's important to note that"`
        '- Avoid Hedging boilerplate: "While X, it is worth considering Y"'
        '- Avoid Rule of three everywhere: "robust, scalable, and efficient"'
        '- Avoid Empty summaries: "In conclusion," restating with no new info'
        '- Avoid Overused words: delve, leverage, seamless, tapestry, testament, underscore, elevate'
        '- Avoid Fake balance: "On one hand... on the other hand" with no stance'
        '- Avoid Vague praise: "great question!", "a powerful tool"'
        '- Avoid Em-dash + parallelism overload, uniform paragraph lengths, no concrete detail'
        '- Avoid Confident but sourceless claims'
        ''
    ]

    export alias pi-reviewer = fnm exec --using default -- node --experimental-strip-types ~/src/config.pi/durable/reviewer.ts

    # one companion runs: open editor with instructions, pipe file to pi, cleanup
    def pi-edit-run [header: list<string>] {
        need "pi"
        let tmp = (mktemp --suffix .md)
        $header | to text | save $tmp
        nvim '+' $tmp
        (pi
            --no-session
            --model
            gpt-6-luna
            --tools
            read,grep,find,ls
            $"@($tmp)"
        )
        rm $tmp
    }

    export def pi-polite [] {
        pi-edit-run ($ai_slop ++ [
            '- Remove repetition'
            '- Keep meaning'
            '- Be concise'
            '- Be polite'
            ''
            'Given instructions above, fix grammar and rephrase the following text:'
            ''
        ])
    }

    export def pi-research [] {
        pi --skill ~/.pi/agent/skills/feynman
    }

    export def pi-translate [] {
        pi-edit-run [
            '- Translate to english, and make a very concise summary at the end'
            ''
            'Given instructions above, keep intent and translate to english the following text:'
            ''
        ]
    }

    export def pi-audit [] {
        pi-edit-run [
            '- Be concise'
            "- Output format: 'Risky: ...' lines"
            '- Flag overconfident or unverifiable claims'
            '- Do not rewrite unless asked'
            ''
            'Audit the following text for risky/confident-but-sourceless claims. List the risky snippets:'
            ''
        ]
    }

    export def pi-commit-staged [--push(-p)] {
        let staged = git diff --staged --name-only | str trim
        if ($staged | is-empty) {
            print "nothing staged, aborting"
            return
        }
        let prompt = "commit staged files"
        let sys = [
            "You just commit staged files"
            "- be concise"
            "- run `git diff --staged` to derive a good commit message"
            "- if in doubt guess message, dont ask"
            "- use semantic commits format"
            "- if commit fails check previous commits structure and repeat" ""
        ]
        (pi --system-prompt ($sys | str join " ") --tools read,bash,grep,find,ls --no-extensions
         --no-skills
         --no-prompt-templates --no-context-files --no-session -p $prompt)
        if $push { git push }
    }
    export alias magic-commit = pi-commit-staged

    export def magic-exec [...prompt: string] {
        if ($prompt | is-empty) { error make {msg: "<prompt> missing"} }
        need "pi"
        let sys = [
            "You translate requests into nushell."
            "Output ONLY a raw JSON object, no markdown, no code fences, no explanation, with two string fields:"
            "1. cmd: a single nu command that does the request with the concrete values given."
            "2. def: a reusable `export def <kebab-name> [<typed params with sensible defaults>] { ... }` that generalizes the request, turning the concrete values into parameters. Pretty formatted."
        ]
        # Only --system-prompt shapes the output: no tools, extensions, skills, templates or context files.
        let raw = (
            pi --system-prompt ($sys | str join " ") --no-tools --no-extensions --no-skills
            --no-prompt-templates --no-context-files --no-session -p ($prompt | str join " ")
            | str trim)
        let out = try {
            $raw | from json
        } catch {
            error make {msg: $"pi returned invalid JSON:\n($raw)"}
        }
        let cmd = $out.cmd? | default '' | str trim
        let def = $out.def? | default '' | str trim
        if ($cmd | is-empty) { error make {msg: "pi returned no command"} }
        if ($def | is-not-empty) {
            print $"(ansi green)# reusable function, paste into your config or a module:(ansi reset)"
            print $def
            print ""
        }
        print $"(ansi cyan)($cmd)(ansi reset)"
        # runs in a child process: $env and cd changes do NOT reach the current shell
        if (input "Run it? [y/N] " | str lowercase) in [y yes] {
            ^nu -c $cmd
        } else {
            print "aborted"
        }
    }

    export def "llm download" [] {

        # Quantizers:         unsloth, lmstudio-community, bartowski, mradermacher
        # Uncensored makers:  huihui-ai, LuffyTheFox, HauhauCS
        #
        # Alternate 27B quants (swap into the table if wanted):
        #   "*UD-Q4_K_M*"   |  "*UD-IQ4_XS*"

        need "hf"

        let base = "~/models" | path expand

        let models = [
            [repo, include, dir];
            [unsloth/Qwen3.6-35B-A3B-GGUF, ["*UD-Q4_K_M*" "*mmproj*"], qwen3.6-35b-a3b]
            [unsloth/Qwen3.8-27B-GGUF, ["Qwen3.8-27B-UD-IQ4_XS.gguf"], qwen3.8-27b]
            [huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF, ["*abliterated-Q4_K.gguf"], qwen3.8-27b-abl]
            [google/gemma-4-26B-A4B-it-qat-q4_0-gguf, [], gemma-4-26b-a4b]
            [unsloth/gemma-4-12B-it-qat-GGUF, ["*UD-Q4_K_XL*"], gemma-4-12b]
        ]

        mkdir $base

        for m in $models {
            mut args = [
                download
                $m.repo
                --local-dir
                ($base | path join $m.dir)
            ]
            for i in ($m.include | default []) { $args = ($args | append [--include $i]) }
            print $"==> ($m.repo)"
            ^hf ...$args
        }
    }

    # Model folder names under ~/models (used for tab-completion)
    def model-names [] {
        ls ("~/models" | path expand) | where type == dir | get name | path basename
    }

    # Pick the main GGUF in a folder: skip mmproj files, prefer shard 00001, else the shallowest file
    def find-gguf [dir: string] {
        let files = (
            glob $"($dir)/**/*.gguf"
            | where {|f| not ($f | str lowercase | str contains "mmproj") }
        )
        if ($files | is-empty) { error make {msg: $"no .gguf found in ($dir)"} }

        let shard1 = $files | where {|f| $f =~ '-00001-of-\d+\.gguf$' }
        if not ($shard1 | is-empty) {
            $shard1 | first
        } else {
            $files | sort-by {|f| $f | path split | length } | first
        }
    }

    export def "llm list" [] {
        let base = "~/models" | path expand
        model-names | each {|n|
            let f = find-gguf ($base | path join $n)
            { model: $n, file: ($f | path basename), size: (ls $f | first | get size) }
        }
    }

    # profile defaults
    # (prefill chunk), kv = KV-cache type.

    const DEFAULTS = {
        ctx: 16384 # ctx = context window (tokens)
        b: 2048 # b = logical batch
        ub: 512 # ub = physical batch
        kv: "f16"
    }

    # Note: Values are starting points, not measured optima.
    def builtin-profiles [] {
        let small_ctx = 32768
        let big_ctx = 65536
        [
            [model, ctx, ub, kv, why];
            ["qwen3.6-35b-a3b", $small_ctx, 512, "q8_0", "MoE ~21 GB, 3B active: fastest decode"]
            ["gemma-4-26b-a4b", $big_ctx, 512, "f16", "MoE ~14 GB, 3.8B active"]
            ["qwen3.8-27b", $small_ctx, 512, "q8_0", "dense ~13 GB: slow decode"]
            ["gemma-4-12b", $big_ctx, 512, "f16", "small ~8 GB"]
            ["qwen3.5-9b", $big_ctx, 512, "f16", "fast helper"]
        ]
    }

    def tuned-path [] {
        "~/models/profiles.json" | path expand
    }

    # Precedence: CLI flag > tuned file > built-in table > DEFAULTS
    def profile-for [name: string] {
        let tuned = if (tuned-path | path exists) {
            open (tuned-path)
        } else {
            []
        }

        let b = (
            builtin-profiles
            | where model == $name
            | get -o 0
            | default {}
        )

        let t = (
            $tuned
            | where model == $name
            | get -o 0
            | default {}
        )

        $DEFAULTS | merge $b | merge $t
    }

    # Reports devices exposed by the llama.cpp executable.
    def llama-device-info [] {
        let r = (try {
            ^llama server --list-devices | complete
        } catch {
            null
        })

        if $r == null {
            return {
                backend: "unknown"
                output: "Could not execute llama server --list-devices"
            }
        }

        let output = $"($r.stdout)\n($r.stderr)"

        let backend = if ($output | str contains "SYCL") {
            "SYCL"
        } else if ($output | str contains "Vulkan") {
            "Vulkan"
        } else if ($output | str contains "CUDA") {
            "CUDA"
        } else if ($output | str contains "CPU") {
            "CPU / GPU not detected"
        } else {
            "unknown"
        }

        {backend: $backend, output: $output}
    }

    # Show available compute devices.
    export def "llm devices" [] {
        let info = (llama-device-info)

        print $"llama.cpp backend: ($info.backend)"
        print $info.output

        print "\nIntel SYCL runtime:"
        try {
            ^sycl-ls
        } catch {
            print "sycl-ls unavailable."
        }

        print "\nGPU device nodes:"
        ls -l /dev/dri/
    }

    # memory diagnostics
    export def "llm memory" [] {
        print "System memory:"
        ^free -h

        print "\nLargest memory consumers:"
        ^ps -eo pid,comm,rss,%mem --sort=-rss
        | head -n 16

        print "\nSwap:"
        ^swapon --show
    }

    # list profiles
    export def "llm profiles" [] {
        let tuned = if (tuned-path | path exists) {
            open (tuned-path)
        } else {
            []
        }

        print "Built-in:"
        print (builtin-profiles | select model ctx ub kv why)

        print "Tuned overrides:"
        print $tuned
    }

    # Gracefully stop llama.cpp: SIGTERM, wait, SIGKILL only with --force.
    export def "llm stop" [--timeout(-t): duration = 30sec, --force(-f)] {
        let pids = ps | where name =~ '^llama' | get pid
        if ($pids | is-empty) {
            print "no llama process running"
            return
        }

        print $"SIGTERM -> ($pids | str join ', ')"
        for p in $pids { kill --signal 15 $p }

        let deadline = (date now) + $timeout
        mut left = $pids
        while ($left | is-not-empty) and ((date now) < $deadline) {
            sleep 500ms
            let alive = ps | get pid
            $left = ($left | where {|p| $p in $alive })
        }

        if ($left | is-empty) {
            print "stopped cleanly"
            return
        }
        if $force {
            print $"still alive, SIGKILL -> ($left | str join ', ')"
            for p in $left { kill --force $p }
        } else {
            print $"still running after ($timeout): ($left | str join ', '). Retry with --force"
        }
    }

    # run model
    export def "llm run" [
        name?: string@model-names
        --ctx(-c): int
        --ub: int
        --port(-p): int = 8080
        --host: string = "127.0.0.1"
        --ngl: int = 99
        --vision(-v)
        --cli
        ...extra: string
    ] {
        need "llama"

        let base = "~/models" | path expand

        let model = if $name == null {
            model-names | input list "Model"
        } else {
            $name
        }

        if $model == null { return }

        let dir = $base | path join $model
        let gguf = (find-gguf $dir)
        let p = (profile-for $model)

        let c = $ctx | default $p.ctx
        let u = $ub | default $p.ub
        # logical batch: at least ubatch, never larger than ctx
        let b = [
            ([$p.b $u] | math max)
            $c
        ] | math min

        let device = (llama-device-info)

        # Flags:
        # -m          model file
        # -c          context window
        # -ngl        number of layers to offload
        # -fa on      flash attention
        # -np 1       single inference slot
        # -b / -ub    logical / physical batch
        # -ctk / -ctv  KV-cache type
        # --alias     API model name
        # --jinja     use model chat template

        mut args = [
            -m
            $gguf
            -c
            $c
            -ngl
            $ngl
            -fa
            on
            -np
            1
            -b
            $b
            -ub
            $u
            -ctk
            $p.kv
            -ctv
            $p.kv
            --alias
            $model
            --jinja
        ]

        if $vision {
            let mm = (glob $"($dir)/**/*mmproj*.gguf")

            if ($mm | is-empty) {
                print "No mmproj found, text-only."
            } else {
                $args = ($args | append [
                    --mmproj
                    ($mm | first)
                ])
            }
        }

        print $"Compute backend: ($device.backend)"
        print $"==> ($gguf | path basename) ctx=($c) ub=($u) kv=($p.kv) ngl=($ngl)"

        if $cli {
            ^llama cli ...$args ...$extra
        } else {
            print $"    http://($host):($port)"
            ^llama server ...$args --host $host --port $port ...$extra
        }
    }

    # Benchmark physical batch sizes and save the fastest for this model.
    export def "llm tune" [name?: string@model-names, --ubs: string = "256,512,1024,2048", --prompt(-p): int = 2048] {
        need "llama"

        let base = "~/models" | path expand

        let model = if $name == null {
            model-names | input list "Model"
        } else {
            $name
        }

        if $model == null { return }

        let gguf = find-gguf ($base | path join $model)
        let p = (profile-for $model)

        print $"==> benchmarking ($model), ubatch: ($ubs)"

        let rows = (
            ^llama bench -m $gguf -ngl 99 -fa on -p $prompt -n 128 -b $p.b -ub $ubs -r 2 -o json | from json
        )

        let pp = $rows | where n_prompt > 0 | sort-by avg_ts --reverse
        let best = $pp | first

        # decode speed of the best ubatch, not a mean across all ubatches
        let tg = (
            $rows
            | where n_gen > 0 and n_ubatch == $best.n_ubatch
            | get avg_ts
            | math avg
            | math round
        )

        print ($pp | select n_ubatch avg_ts)
        print $"best ubatch: ($best.n_ubatch) [prompt ~($best.avg_ts | math round) tok/s, decode ~($tg) tok/s]"

        let path = (tuned-path)

        let old = if ($path | path exists) {
            open $path | where model != $model
        } else {
            []
        }

        $old
        | append {
            model: $model
            ub: $best.n_ubatch
            pp: ($best.avg_ts | math round)
            tg: $tg
            ctx: $p.ctx
        }
        | save -f $path
    }

    # Compare different GPU layer offload levels.
    export def "llm compare" [
        name?: string@model-names
        --ngls: string = "0,8,16,24,99"
        --prompt(-p): int = 2048
        --gen(-n): int = 128
    ] {
        need "llama"

        let base = "~/models" | path expand

        let model = if $name == null {
            model-names | input list "Model"
        } else {
            $name
        }

        if $model == null { return }

        let dir = $base | path join $model
        let gguf = (find-gguf $dir)
        let p = (profile-for $model)

        let candidates = (
            $ngls
            | split row ","
            | each {|n| $n | str trim | into int }
        )

        let device = (llama-device-info)

        print $"==> Comparing ($model)"
        print $"Backend: ($device.backend)"
        print $"Prompt: ($prompt), generation: ($gen)"
        print $"Ubatch: ($p.ub), logical batch: ($p.b)"

        for n in $candidates {
            print $"\n--- GPU layers: ($n) ---"

            let result = (try {
                ^llama bench -m $gguf -ngl $n -fa on -p $prompt -n $gen -b $p.b -ub $p.ub -r 2 -o json | complete
            } catch {
                null
            })

            if $result == null {
                print "Benchmark failed."
            } else if $result.exit_code == 0 {
                # compact table when parseable, raw output otherwise
                let parsed = (
                    try {
                        $result.stdout | from json
                    } catch {
                        null
                    }
                )
                if $parsed == null {
                    print $result.stdout
                } else {
                    let table = ($parsed
                        | try { select n_ubatch n_prompt n_gen avg_ts } catch { null })
                    if $table == null { print $result.stdout } else { print $table }
                }
            } else {
                print $result.stderr
                print ("Failed (exit code: " + ($result.exit_code | into string) + ").")
            }
        }
    }

    # Write/refresh llama.cpp provider in Pi's models.json.
    export def "llm pi-setup" [--port(-p): int = 8080, --host: string = "localhost"] {
        let cfg = "~/.pi/agent/models.json" | path expand
        mkdir ($cfg | path dirname)

        let existing = if ($cfg | path exists) {
            cp $cfg $"($cfg).bak"
            open $cfg
        } else {
            {}
        }

        let providers = $existing | get -o providers | default {}

        let llama = {
            baseUrl: $"http://($host):($port)/v1"
            api: "openai-completions"
            apiKey: "none"
            models: (model-names | each {|n| { id: $n } })
        }

        $existing
        | upsert providers ($providers | upsert "llama-cpp" $llama)
        | save -f $cfg

        print $"Wrote ($cfg)"
    }

    # Launch Pi against a model (server must already be running).
    export def --wrapped "llm pi" [name?: string@model-names, ...rest] {
        let model = if $name == null {
            model-names | input list "Model"
        } else {
            $name
        }

        if $model == null { return }

        ^pi --provider llama-cpp --model $model ...$rest
    }
}

# # See what's installed and the reasoning for each profile
# llm list
# llm profiles
#
# # Measure once per model, then run normally
# llm tune qwen3.6-35b-a3b
# llm tune gemma-4-12b --ubs "512,1024" --prompt 4096    # quicker, longer prompt
# llm run qwen3.6-35b-a3b                                 # uses the tuned ubatch
#
# # Interactive menu (omit the name)
# llm run
#
# # Override anything for one run
# llm run gemma-4-12b --ctx 8192                          # smaller context, less RAM
# llm run qwen3.8-27b --ub 256                            # force a ubatch
# llm run gemma-4-12b --vision                            # load the mmproj file
# llm run qwen3.8-27b --cli                               # terminal chat, no server
# llm run gemma-4-26b-a4b --port 9000 --host 0.0.0.0      # reachable from the LAN
# llm run qwen3.8-27b -- --temp 0.6 --top-p 0.95          # extra llama.cpp flags
#
# # Use with Pi
# llm pi-setup
# llm run gemma-4-26b-a4b      # terminal 1
# llm pi gemma-4-26b-a4b       # terminal 2
#
# # Reset tuning
# rm ~/models/profiles.json
