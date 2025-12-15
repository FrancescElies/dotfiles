set shell := ["nu", "-c"]

alias b := bootstrap

bootstrap: secret-nu-file
  nu bootstrap.nu
  print $"Now you can e.g. (ansi lyu)just get-fedora-pkgs(ansi reset) or (ansi lyu)just get-debian-pkgs(ansi reset) or (ansi lyu)just get-windows-pkgs(ansi reset)"
  print $"Later on e.g. (ansi lyu)just get-rust-pkgs(ansi reset) and/or (ansi lyu)just rust-dev-pkgs(ansi reset)"


[private]
[windows]
secret-nu-file:
  if (not (try { open src/os-this-machine.nu | str contains "use os-windows.nu *" } catch { false })) {"use os-windows.nu *" | save --append src/os-this-machine.nu }

[private]
[macos]
secret-nu-file:
  if (not (try { open src/os-this-machine.nu | str contains "use os-mac.nu *" } catch { false })) {"use os-mac.nu *" | save --append src/os-this-machine.nu }

[private]
[linux]
secret-nu-file:
  if (not (try { open src/os-this-machine.nu | str contains "use os-linux.nu *" } catch { false })) {"use os-linux.nu *" | save --append src/os-this-machine.nu }

# create a python virtual environment
home-venv: bootstrap
  # NOTE: cd not honored between lines, thus everything in one line
  let pkgs = (open packages.toml | get python | transpose | get column0); cd ~; uv venv; uv pip install ...$pkgs

update-imports:
  cog -r config.nu

[windows]
get-windows-pkgs: home-venv
  let pkgs = (open packages.toml | get windows | transpose | get column0); sudo winget install --silent ...$pkgs


[windows]
windows-fix-long-paths:
  input $'(ansi pb)open regedit set HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem LongPathsEnabled to 1.(ansi reset) Done? press enter'
  git config --system core.longpaths true


# https://blog.xoria.org/macos-tips/
[macos]
get mac-pkgs: home-venv
  brew install ...(open packages.toml | get mac-brew | transpose | get column0)
  brew install --cask ...(open packages.toml | get mac-brew-cask | transpose | get column0)

# see https://askubuntu.com/questions/645681/samsung-m2020-on-ubuntu#645949
[unix]
fix-printer-driver-samsung-M2026:
  git clone https://github.com/francescElies/samsung-uld-copy
  cd samsung-uld-copy; just

[unix]
fix-wifi-after-sleep:
  sudo cp fixes/wifi_rand_mac.conf /etc/NetworkManager/conf.d/

[unix]
fix-closed-laptop-lid-should-not-suspend:
  sudo mkdir /etc/systemd/logind.conf.d/
  sudo cp fixes/ignore-closed-lid.conf /etc/systemd/logind.conf.d/ignore-closed-lid.conf

[unix]
get-debian-pkgs: home-venv
  sudo apt remove -y nano
  sudo apt install -y ...(open packages.toml | get debian | transpose | get column0)
  sudo systemctl enable syncthing@cesc.service

[unix]
get-fedora-pkgs: home-venv
  sudo dnf remove -y nano
  sudo dnf install -y ...(open packages.toml | get fedora | transpose | get column0)
  sudo systemctl enable syncthing@cesc.service

get-sops: bootstrap
  start https://github.com/getsops/sops/releases

[private]
[windows]
rustup:
  if (which ^rustup | is-empty ) { input $"(ansi purple_bold)Install https://rustup.rs/(ansi reset) once done press enter." }

[private]
[unix]
rustup: bootstrap
  if (which ^rustup | is-empty ) { curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh }

[private]
rustup-tooling: rustup
  rustup component add llvm-tools rust-analyzer

[private]
cargo-binstall: rustup-tooling
  if (which ^cargo-binstall | is-empty ) { cargo install cargo-binstall }
  cargo binstall -y ...(open packages.toml | get rust-pkgs | transpose | get column0)
  ~/.cargo/bin/broot --install

[windows]
get-rust-pkgs: cargo-binstall
   print done

[unix]
get-rust-pkgs: cargo-binstall
  ~/.cargo/bin/broot --install
  print install binaries
  sudo cp ~/.cargo/bin/broot /usr/local/bin/
  sudo cp ~/.cargo/bin/biodiff /usr/local/bin/
  sudo cp ~/.cargo/bin/git-biodiff /usr/local/bin/
  sudo cp ~/.cargo/bin/hs /usr/local/bin/
  sudo cp ~/.cargo/bin/tldr  /usr/local/bin/
  sudo cp ~/.cargo/bin/difft  /usr/local/bin/
  sudo cp ~/.cargo/bin/btm   /usr/local/bin/
  sudo cp ~/.cargo/bin/ouch  /usr/local/bin/

get-rust-pkgs-dev: cargo-binstall
  cargo binstall -y ...(open packages.toml | get rust-dev-pkgs | transpose | get column0)

