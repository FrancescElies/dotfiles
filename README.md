# dotfiles

> [!NOTE]
> [omakub](https://omakub.org/)
> [nu-scripts](https://github.com/nushell/nu_scripts)

##  Requirements
<details><summary> Linux </summary>

```nu
curl -fsSL https://apt.fury.io/nushell/gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/fury-nushell.gpg
echo "deb https://apt.fury.io/nushell/ /" | sudo tee /etc/apt/sources.list.d/fury.list
sudo apt update
sudo apt install -y build-essential nushell just cmake

# or
sudo apt install -y rustup
rustup install stable
cargo install nu
```

</details>

<details><summary> Mac </summary>

```nu
brew install just nushell
```

</details>

<details><summary> Windows </summary>

```nu
winget install --silent --id Casey.Just Nushell.Nushell
```

</details>

##  Install
```nu
mkdir ~/src
git clone https://github.com/FrancescElies/dotfiles ~/src/dotfiles
cd ~/src/dotfiles
overlay use toolkit
toolkit bootstrap
```

## Firefox
`about:profiles` click Open Folder in the Root Directory section add a
`user.js` and paste contents from
[BetterFox](https://github.com/yokoffing/BetterFox?tab=readme-ov-file)

Some extensions: ublock, decentraleyes, still don't care about cookies, privacy badger, vimium

`about:config`
| setting | value |
| ------- | ----- |
| `sidebar.verticalTabs` | true |
| `browser.sessionstore.restore_on_demand` | false |


### Vimium
Mapping for when using vertical tabs
```
map J nextTab
map K previousTab
```

## Links
- https://www.nushell.sh/blog/2023-08-23-happy-birthday-nushell-4.html
- https://github.com/dandavison/dotfiles
- https://github.com/nushell/nu_scripts

# share your keystrokes
Mac: KeyCastr
Linux/Win/Mac: https://github.com/mulaRahul/keyviz
