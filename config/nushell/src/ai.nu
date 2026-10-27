module completions {
    export def --wrapped pi [...args] {
        match $nu.os-info.name {
            "windows" => {
                # WARN: calling pi (pi.cmd) directly breaks scrolling
                let cli_js = ([
                    ($env.FNM_DIR | path join "aliases" "default")
                    'installation\node_modules\@earendil-works\pi-coding-agent\dist\cli.js'] | path join)
                print $'running `node ($cli_js)'
                fnm exec --using default -- node  $cli_js ...$args
            },
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
        pi --no-session --model gpt-6-luna --tools read,grep,find,ls $"@($tmp)"
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
        pi --no-session --model gpt-6-luna --tools read,grep,find,ls $"@($tmp)"
        rm $tmp
    }

    export def pi-audit [] {
        let header = [
          "- Be concise"
          "- Output format: 'Risky: ...' lines"
          "- Flag overconfident or unverifiable claims"
          "- Do not rewrite unless asked"
          ""
          "Audit the following text for risky/confident-but-sourceless claims. List the risky snippets:"
          ""
        ]
        let tmp = (mktemp --suffix .md)
        $header | to text | save --append $tmp
        nvim '+' $tmp
        pi --no-session --model gpt-6-luna --tools read,grep,find,ls $"@($tmp)"
        rm $tmp
    }

    export def pi-commit-staged [--push (-p)] {
        let prompt = "commit staged files"
        let sys = [
          "You just commit staged files"
          "- be concise"
          "- run `git diff --staged` to derive a good commit message"
          "- if in doubt guess message, dont ask"
          "- use semantic commits format"
          "- if commit fails check previous commits structure and repeat"
          ""
        ]
       (pi --system-prompt ($sys | str join " ") --tools read,bash,grep,find,ls --no-extensions
         --no-skills --model gpt-6-luna
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
       let out = try { $raw | from json } catch { error make {msg: $"pi returned invalid JSON:\n($raw)"} }
       let cmd = ($out.cmd? | default '' | str trim)
       let def = ($out.def? | default '' | str trim)
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

}

export use completions *
