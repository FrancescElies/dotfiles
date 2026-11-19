module completions {
    export def --wrapped pi [--sandboxed, --share: list<string>, ...args] {
        if $sandboxed {
            mut mounts = [
                -v
                $"(pwd):/workspace"
                -v
                $"(($env.HOME)/.pi/agent | path expand):/root/.pi/agent"
                -v
                $"(($env.HOME)/.gitconfig | path expand):/root/.gitconfig:ro"
            ]
            for p in ($share | default []) {
                let hp = $p | path expand
                let name = $hp | path basename
                $mounts = ($mounts | append [-v $"($hp):/shared/($name)"])
            }
            podman run --rm -it ...$mounts localhost/pi ...$args
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
                }
                print $'running `node ($cli_js)'
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
        `- Avoid Hedging boilerplate: "While X, it's worth considering Y"`
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

    export def pi-polite [] {
        let header = $ai_slop ++ [
            '- Remove repetition'
            '- Keep meaning'
            '- Keep meaning'
            '- Be concise'
            '- Be polite'
            ''
            'Given instructions above, fix grammar and rephrase the following text:'
            ''
        ]
        let tmp = (mktemp --suffix .md)
        $header | to text | save --append $tmp
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

    export def pi-research [] {
        pi --skill ~/.pi/agent/skills/feynman
    }

    export def pi-translate [] {
        let header = [
            '- Translate to english, and make a very concise summary at the end'
            ''
            'Given instructions above, keep intent and translate to english the following text:'
            ''
        ]
        let tmp = (mktemp --suffix .md)
        $header | to text | save --append $tmp
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

    export def pi-audit [] {
        let header = [
            "- Be concise"
            "- Output format: 'Risky: ...' lines"
            "- Flag overconfident or unverifiable claims"
            "- Do not rewrite unless asked" ""
            "Audit the following text for risky/confident-but-sourceless claims. List the risky snippets:"
            ""
        ]
        let tmp = (mktemp --suffix .md)
        $header | to text | save --append $tmp
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

    export def pi-commit-staged [--push(-p)] {
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
        let sys = [
            "You translate requests into nushell."
            "Output ONLY a raw JSON object, no markdown, no code fences, no explanation, with two string fields:"
            "1. cmd: a single nu command that does the request with the concrete values given."
            "2. def: a reusable `export def <kebab-name> [<typed params with sensible defaults>] { ... }` that generalizes the request, turning the concrete values into parameters. Pretty formated"
        ]
        # Only --system-prompt shapes the output: no tools, extensions, skills, templates or context files.
        let raw = (
           pi --system-prompt ($sys | str join " ") --no-tools --no-extensions --no-skills
            --no-prompt-templates --no-context-files --no-session -p ($prompt | str join " ")
           | str trim
           | str replace -r '^```\w*\s*' '' | str replace -r '\s*```$' '' | str trim)
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
        if (input "Run it? [y/N] " | str lowercase) in [y yes] {
            ^nu -c $cmd
        } else {
            print "aborted"
        }
    }

    export def --env pidocs [] {
        let root = match $nu.os-info.name {
            "windows" => (fnm exec --using default -- npm.cmd root -g)
            _ => (fnm exec --using default -- npm root -g)
        }
        let docs = $root | str trim | path join "@earendil-works/pi-coding-agent/docs"
        nvim -c $'cd ($docs)' -c 'e index.md'
    }

    export def "download ai-models 32gb" [] {

        # Quantizers:         unsloth, lmstudio-community, bartowski, mradermacher
        # Uncensored makers:  huihui-ai, LuffyTheFox, HauhauCS
        #
        # Alternate 27B quants (swap into the table if wanted):
        #   "*UD-Q4_K_M*"   |  "*UD-IQ4_XS*"

        let base = "~/models" | path expand

        let models = [
            [repo, include, dir];
            [unsloth/Qwen3.6-35B-A3B-GGUF, "*UD-Q4_K_M*", qwen3.6-35b-a3b]
            [unsloth/Qwen3.8-27B-GGUF, "Qwen3.8-27B-UD-IQ4_XS.gguf", qwen3.8-27b]
            [huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF, "*abliterated-Q4_K.gguf", qwen3.8-27b-abl]
            [google/gemma-4-26B-A4B-it-qat-q4_0-gguf, null, gemma-4-26b-a4b]
            [unsloth/gemma-4-12B-it-qat-GGUF, "*UD-Q4_K_XL*", gemma-4-12b]
        ]

        mkdir $base

        for m in $models {
            mut args = [
                download
                $m.repo
                --local-dir
                ($base | path join $m.dir)
            ]
            if $m.include != null {
                $args = ($args | append [--include $m.include])
            }
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

    # ---- profile defaults -------------------------------------------------------
    # ctx = context window (tokens), b = logical batch, ub = physical batch (prefill
    # chunk), kv = KV-cache type.
    const DEFAULTS = {
        ctx: 16384
        b: 2048
        ub: 512
        kv: "f16"
    }

    # Memory budget on 32 GB shared RAM: ~4-6 GB for the OS and apps, the rest for
    # model weights + KV cache + scratch buffers.
    def builtin-profiles [] {
        [[model             ctx   ub    kv      why];
     # ~21 GB weights leaves only ~5-6 GB for everything else, so KV is quantized
     # to q8_0 as a precaution (halves KV memory). MoE with 3B active -> a larger
     # ubatch (1024) feeds the GPU bigger chunks during prefill. Both are guesses.
     ["qwen3.6-35b-a3b" 32768 1024 "q8_0"  "tight RAM: q8 KV; MoE: bigger ubatch"]
     # ~13 GB (UD-IQ4_XS), so plenty of headroom: keep f16 KV for quality.
     # Dense models do far more compute per token, so the default ubatch (512)
     # is a safe start; larger batches use more scratch memory for little gain (guess).
     ["qwen3.8-27b"     32768 512  "f16"    "dense: default ubatch, ample RAM"]
     # ~16 GB (Q4_K): same reasoning as the dense 27B.
     ["qwen3.8-27b-abl" 32768 512  "f16"    "dense, ~16 GB: default ubatch"]
     # 14.4 GB QAT, 3.8B active MoE: bigger ubatch like the other MoE. f16 KV fits
     # easily. KV size for Gemma 4 not verified, so lower ctx if it swaps.
     ["gemma-4-26b-a4b" 32768 1024 "f16"    "MoE, 14.4 GB: bigger ubatch, f16 KV"]
     # ~8 GB, tiny footprint: bigger ubatch costs little memory, f16 KV is fine.
     ["gemma-4-12b"     32768 1024 "f16"    "small: bigger ubatch is cheap"]]
    }

    def tuned-path [] {
        "~/models/profiles.json" | path expand
    }

    # Precedence: CLI flag > tuned file > built-in table > DEFAULTS
    def profile-for [name: string] {
        let tuned = if (tuned-path | path exists) { open (tuned-path) } else { [] }
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

    # Show the built-in profiles with their reasoning, plus any tuned overrides
    export def "llm profiles" [] {
        let tuned = if (tuned-path | path exists) { open (tuned-path) } else { [] }
        print "Built-in:"
        print (builtin-profiles | select model ctx ub kv why)
        print "Tuned (override ub):"
        print $tuned
    }

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
        let b = ([$p.b $u] | math max) # logical batch must be >= physical batch

        # Flags:
        #  -m        model file
        #  -c        context window; Pi's prompt is ~16K tokens in your log, so 16384
        #            leaves no room and 32768 is the next step up (KV memory scales with it)
        #  -ngl 99   offload all layers to the iGPU
        #  -fa on    flash attention; also required for quantized KV (-ctk/-ctv)
        #  -np 1     one slot: all context goes to one conversation and one prompt cache
        #            (more slots split the context and cache)
        #  -b / -ub  logical/physical batch; prefill speed depends mainly on -ub
        #  -ctk/-ctv KV-cache type (f16 = full quality, q8_0 = half the memory)
        #  --alias   model name the API reports, so Pi's models.json id matches
        #  --jinja   use the model's chat template, needed for tool calls
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
            if ($mm | is-empty) { print "No mmproj found, text-only." } else {
                $args = ($args | append [
                    --mmproj
                    ($mm | first)
                ])
            }
        }

        print $"==> ($gguf | path basename)  ctx=($c) ub=($u) kv=($p.kv)"
        if $cli {
            ^llama cli ...$args ...$extra
        } else {
            print $"    http://($host):($port)"
            ^llama server ...$args --host $host --port $port ...$extra
        }
    }

    # Benchmark ubatch sizes and save the fastest as this model's profile
    export def "llm tune" [
    name?: string@model-names
    --ubs: string = "256,512,1024,2048"   # candidates to try
    --prompt (-p): int = 2048             # prompt length for the test
] {
        let base = "~/models" | path expand
        let model = if $name == null {
            model-names | input list "Model"
        } else {
            $name
        }
        if $model == null { return }
        let gguf = find-gguf ($base | path join $model)

        print $"==> benchmarking ($model), ubatch: ($ubs)"
        let rows = (
        ^llama bench -m $gguf -ngl 99 -fa 1 -p $prompt -n 128 -b 2048 -ub $ubs -r 2 -o json
        | from json
    )

        let pp = $rows | where n_prompt > 0 | sort-by avg_ts --reverse
        let tg = (
            $rows
            | where n_gen > 0
            | get avg_ts
            | math avg
            | math round
        )
        let best = $pp | first

        print ($pp | select n_ubatch avg_ts)
        print $"best ubatch: ($best.n_ubatch) \(prompt ~($best.avg_ts | math round) tok/s, decode ~($tg) tok/s\)"

        let path = (tuned-path)
        let old = if ($path | path exists) {
            open $path | where model != $model
        } else {
            []
        }
        $old
        | append { model: $model, ub: $best.n_ubatch, pp: ($best.avg_ts | math round), tg: $tg }
        | save -f $path
    }

    # Write/refresh the llama-cpp provider in Pi's models.json (keeps other providers, backs up the old file)
    export def "llm pi-setup" [--port(-p): int = 8080, --host: string = "localhost"] {
        let cfg = "~/.pi/agent/models.json" | path expand
        mkdir ($cfg | path dirname)

        let existing = if ($cfg | path exists) {
            cp $cfg $"($cfg).bak"
            open $cfg
        } else { {} }

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

    # Launch Pi against a model (the server must already be running via `llm run`)
    export def "llm pi" [name?: string@model-names] {
        let model = if $name == null {
            model-names | input list "Model"
        } else {
            $name
        }
        if $model == null { return }
        ^pi --provider llama-cpp --model $model
    }
}

export use completions *

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
