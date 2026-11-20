# dotfiles/config/nushell

## Install
Install [just](https://github.com/casey/just?tab=readme-ov-file#packages)
`apt install just` or `dnf install just` or `winget install --silent --id Casey.Just`

## Nushell version

Use Nushell 0.117 or newer. Custom completers use the named `token`, `place`, and `buffer` inputs.

## Project trust

Review a project's `env.nu` and toolkit code before granting trust:

```nu
project trust ~/src/my-project
project trusted
project untrust ~/src/my-project
```

Start with an empty allowlist. Grant trust to each exact directory where you want project hooks; child directories do not inherit trust. The hooks load local `env.nu` and toolkit modules, run `fnm use` when Node version files exist, and add Cargo build directories to PATH.

Re-enter the directory after changing trust. On leaving, the hooks unload the project environment overlay and remove the Rust paths they added. Revoking trust prevents future loads; it cannot undo actions that project code has already taken or remove toolkit commands you already imported.

Store the allowlist in `$nu.data-dir/trusted-projects.nuon`. Set `DOTFILES_PROJECT_TRUST_FILE` to use another file, such as an isolated test fixture.

## Picker shortcuts

- Ctrl+T: insert an fd/fzf file selection as a quoted Nushell path.
- Alt+C: choose a subdirectory with `input list --fuzzy`.
- Alt+Shift+C: choose a project with `goto`.
- Ctrl+U: choose a Nushell module to import.
- Alt+U: go to the repository root with `cdroot`.

Cancel a picker to leave the directory or command line unchanged. Re-source `config.nu` without duplicating its menus, bindings, or tagged hooks; retain Nu's default Tab bindings and third-party hooks.

## Tests

Run from the repository root:

```nu
nu --no-config-file config/nushell/tests/runtime.nu
nu --no-config-file --interactive config/nushell/tests/completions.nu
nu --env-config config/nushell/env.nu --config config/nushell/config.nu --interactive config/nushell/tests/config.nu
```

The completion tests require Git and Just. The config test sources your full config, including machine-local setup. Use `--interactive` for completion tests so `commandline complete` can access the completion engine.

## Links
- https://www.nushell.sh/blog/2023-08-23-happy-birthday-nushell-4.html
- https://github.com/dandavison/dotfiles/config/nushell
- https://github.com/nushell/nu_scripts

