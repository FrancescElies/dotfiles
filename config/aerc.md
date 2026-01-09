Tweaks to the default config

`aerc.conf`
```conf
[ui]
index-columns=flags:4,name<20%,subject,date>=,size>=
# Adds email size column
column-size={{.Size | humanReadable}}
```

`accounts.conf`

```
[posteo]
source        = imaps://ryvrf%40posteo.net@posteo.de:993
outgoing      = smtps://ryvrf%40posteo.net@posteo.de:465
default       = INBOX
from          = senaprfp ryvrf <ryvrf@posteo.net>
cache-headers = true

archive = Archives
source-cred-cmd = secret-tool lookup service aerc-imap ryvrf ryvrf@posteo.net
outgoing-cred-cmd = secret-tool lookup service aerc-smtp ryvrf ryvrf@posteo.net
```

`binds.conf`
```
[messages]
ff = :filter -f<space> "{{index (.From | emails) 0}}" <Enter> # filter mails from current sender
fw = :filter -d this_week <Enter>
ft = :filter -d today <Enter>
fs = :filter -H<space> subject:"{{.SubjectBase}}" <Enter> # filter mails with the same subject
fS = :filter -H<space> subject:<Space> # filter mails with desired subject

```
