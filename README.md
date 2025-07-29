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
sudo apt install nushell just
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

## Links
- https://www.nushell.sh/blog/2023-08-23-happy-birthday-nushell-4.html
- https://github.com/dandavison/dotfiles
- https://github.com/nushell/nu_scripts

