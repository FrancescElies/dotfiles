module completions {
    export def --wrapped pi [...args] {
        match $nu.os-info.name {
            "windows" => {
                fnm exec --using v25 -- pi.cmd ...$args
            },
            _ => {
                fnm exec --using v25 -- pi ...$args
            }
        }
    }

    export def --env pi-env [] { fnm use v25 }

    export def --env pi-docs [] {
        let root = match $nu.os-info.name {
            "windows" => (fnm exec --using v25 -- npm.cmd root -g)
            _ => (fnm exec --using v25 -- npm root -g)
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
        pi --no-session --model claude-haiku-4.5 --tools read,grep,find,ls $"@($tmp)"
        rm $tmp
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
        pi --no-session --model claude-haiku-4.5 --tools read,grep,find,ls $"@($tmp)"
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
        pi --no-session --model claude-haiku-4.5 --tools read,grep,find,ls $"@($tmp)"
        rm $tmp
    }
}

export use completions *
