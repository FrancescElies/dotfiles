set shell := ["nu", "-c"]

alias b := bootstrap

bootstrap:
    use toolkit.nu; toolkit bootstrap
