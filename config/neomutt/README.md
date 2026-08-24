## What's Included

- **muttrc**, Main configuration with sensible defaults
- **bindings**, Vim-inspired keybindings (extensible)
- **colors**, Clean, minimal color scheme
- **accounts.muttrc.example**, Multi-account setup examples (Gmail, Outlook, ProtonMail, etc.)
- **README.md**, This guide

## Quick Start

### 1. Prerequisites

Install NeoMutt (and optional tools):

```bash
# macOS
brew install neomutt msmtp

# Ubuntu/Debian
sudo apt install neomutt msmtp

# Fedora
sudo dnf install neomutt msmtp

# Arch
sudo pacman -S neomutt msmtp
```

### 2. Clone or Copy

```bash
# Clone (if on GitHub)
git clone https://github.com/yourusername/neomutt-kickstart ~/.config/neomutt

# Or manually copy files:
mkdir -p ~/.config/neomutt
cp muttrc ~/.config/neomutt/
cp bindings ~/.config/neomutt/
cp colors ~/.config/neomutt/
```

### 3. Configure Your Email

Edit `~/.config/neomutt/muttrc` and update:

```muttrc
set realname = "Your Name"
set from = "your.email@example.com"
```

### 4. Set Up IMAP/SMTP

#### Option A: Simple IMAP (Recommended for beginners)

Uncomment and edit the IMAP section in `muttrc`:

```muttrc
set imap_user = "your.email@example.com"
set imap_pass = "your-password"
set imap_keepalive = 900
set mail_check = 60
set timeout = 15
```

⚠️ **Security:** Storing plain passwords is risky. See Option B below.

#### Option B: Use msmtp + GPG (Recommended)

1. **Install msmtp:**
```bash
brew install msmtp # or apt, dnf, pacman
```

2. **Create msmtp config** (`~/.config/msmtp/config`):
```
defaults
auth on
tls on
logfile ~/.local/share/msmtp/msmtp.log

account gmail
host smtp.gmail.com
port 587
from your.email@gmail.com
user your.email@gmail.com
password your-app-specific-password

account default : gmail
```

3. **Secure it:**
```bash
chmod 600 ~/.config/msmtp/config
```

4. **Update muttrc:**
```muttrc
set sendmail = "/usr/bin/msmtp -a default"
```

#### Option C: Use GPG-encrypted passwords

Create `~/.mutt/passwords.gpg` with your credentials (encrypted):

```bash
# Create and edit encrypted file
gpg , edit-key $(gpg , list-keys | grep uid | head -1 | awk '{print $NF}')

# Then in muttrc:
set imap_pass = "`gpg2 -dq ~/.mutt/passwords.gpg | grep 'imap_pass:' | cut -d: -f2`"
```

### 5. Set Up Multiple Accounts (Optional)

Copy and edit the example:

```bash
cp accounts.muttrc.example ~/.config/neomutt/accounts.muttrc
```

Then edit `accounts.muttrc` with your accounts. Uncomment the section in `muttrc`:

```muttrc
source ~/.config/neomutt/accounts.muttrc
```

### 6. Create Mailbox Directories (if using Maildir)

```bash
mkdir -p ~/Mail/{INBOX,Sent,Drafts,Trash,Archive}
```

### 7. Test It

```bash
neomutt
```

If it starts without errors, you're good! Press `?` to see keybindings.

## Configuration Structure

```
~/.config/neomutt/
├── muttrc # Main config (edit this first)
├── bindings # Vim-like keybindings
├── colors # Color scheme
├── accounts.muttrc # Multi-account setup
└── mailcap # Attachment handlers (optional)
```

Each file is standalone and well-commented. Add new features by:
1. Creating a new file (e.g., `hooks.muttrc`)
2. Sourcing it in `muttrc`: `source ~/.config/neomutt/hooks.muttrc`

## Common Customizations

### Change Editor

```muttrc
set editor = "nvim" # or vim, emacs, nano, etc.
```

### Show HTML Emails

Install lynx or w3m, then update `mailcap`:

```bash
cat > ~/.config/neomutt/mailcap << 'EOF'
text/html; lynx -dump -force_html %s; nametemplate=%s.html; copiousoutput
EOF
```

### Customize Keybindings

Edit `~/.config/neomutt/bindings`. Example:

```muttrc
bind index j next-entry # j to go down
bind index k previous-entry # k to go up
bind index < previous-page # < to page up
bind index > next-page # > to page down
```

### Add Search (notmuch integration)

```bash
# Install notmuch
brew install notmuch

# Index your mail
notmuch new

# Then add to muttrc:
bind index S vfolder-from-query # Search
```

### Customize Colors

Edit `~/.config/neomutt/colors`. Available colors:

```muttrc
color index cyan default '.*' # All messages
color index red default 'from john' # Specific sender
color index green default '~N' # Unread
```

See `man muttrc` for more color options.

## Troubleshooting

### "Connection refused"
- Check IMAP/SMTP server details (imap.gmail.com, smtp.gmail.com, etc.)
- Ensure firewall allows port 587/993
- For Gmail: enable "Less secure apps" or use app-specific password

### "Authentication failed"
- Verify credentials in muttrc
- Check that passwords are correct
- For Gmail: use app-specific password, not regular password

### "No mailboxes"
- Check that `folder` path exists and is readable
- If using Maildir: create folders manually: `mkdir -p ~/Mail/{INBOX,Sent,Drafts}`
- Verify path in `mailboxes` line matches your setup

### "Empty index"
- Run `mail` or `fetchmail` first to sync messages
- Or check `mail_check` and `timeout` settings

### Keybindings not working
- Press `?` in any view to see current bindings
- Ensure no terminal conflicts (check `stty -a`)
- Verify bindings are sourced in muttrc

## Next Steps

1. **Learn keybindings**, Press `?` in any view. Start with: `j/k` (up/down), `l` (open), `r` (reply), `d` (delete)
2. **Explore settings**, Read the default `muttrc` comments; tweak to your workflow
3. **Add hooks**, Auto-actions based on folder or sender (see `man muttrc` → `folder-hook`, `send-hook`)
4. **Integrate tools**, notmuch (search), urlview (links), w3m/lynx (HTML), etc.
5. **Join the community**, r/neomutt, [neomutt docs](https://neomutt.org/guide/)

## Resources

- **Official Docs:** https://neomutt.org/
- **Manual:** `man neomutt`, `man muttrc`
- **FAQ:** https://neomutt.org/guide/faq
- **Config Examples:** https://github.com/neomutt/neomutt/tree/main/samples

## Tips for Ease of Use

1. **Start minimal**, Don't enable everything at once
2. **Use vim-like keys**, Consistent with other CLI tools
3. **Sidebar navigation**, Press `Ctrl+P`/`Ctrl+N` to switch folders
4. **Limit threads**, Press `+` to filter/limit messages
5. **Mark as read**, Space in index to mark current thread
6. **Search**, Press `/` to search within current folder
7. **Tag messages**, Press `t` to tag, then `T` for pattern tag

,

Questions? Check the [official NeoMutt docs](https://neomutt.org/) or ask in r/neomutt.

