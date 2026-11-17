# OSC 7501 status for long-running scripts, shown in the Zellij inbox.
# https://zellij.dev/documentation/inbox.html#osc-7501
#
# states: working | done | blocked | error | clear
# msg is base64-encoded so it can carry spaces and colons.

export def osc7501 [state: string, --msg: string] {
    let body = [$"state=($state)"]
        | append (if $msg != null { $"msg=($msg | encode base64)" } else { [] })
        | str join ":"
    print -n $"\e]7501;($body)\e\\"
}

# Run `action` while reporting working -> done/error to the inbox.
# Errors are reported and then re-raised.
export def with-status [label: string, action: closure] {
    osc7501 "working" --msg $label
    try {
        do $action
    } catch { |err|
        osc7501 "error" --msg $"($label) failed: ($err.msg)"
        error make { msg: $err.msg }
    }
    osc7501 "done" --msg $"($label) finished"
}
