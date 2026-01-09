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
  ff = :filter -f<space> "{{index (.From | emails) 0}}" <Enter> # filter mails from current sender
  fs = :filter -H<space> subject:"{{.SubjectBase}}" <Enter> # Show Mails with the same subject
  fS = :filter -H<space> subject:<Space> # filter mails with subject e.g. "fs foo" filters mails with subject containing "foo"
```
