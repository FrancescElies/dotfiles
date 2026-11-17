set shell := ["nu", "-c"]

alias b := bootstrap

bootstrap:
    use toolkit.nu; toolkit bootstrap

# run bootstrap in a watched Zellij pane (notifies in the inbox when it finishes)
bootstrap-watched:
    zellij run --notify -- nu -c "use toolkit.nu; toolkit bootstrap"
