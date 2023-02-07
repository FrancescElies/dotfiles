export def --wrapped main [page: string@"nu-complete pages" --section=null: number@"nu-complete sections" ...rest] {
  with-env {
    # blinking mode (not common in manpages)
    LESS_TERMCAP_mb: $'(ansi rb)'
    # double-bright mode (used for boldface)
    LESS_TERMCAP_md: $'(ansi rb)'
    # exit/reset all modes
    LESS_TERMCAP_me: $'(ansi reset)'
    # enter standout mode (used by the less statusbar and search results)
    LESS_TERMCAP_so: $'(ansi yr)'
    # exit standout mode
    LESS_TERMCAP_se: $'(ansi reset)'
    # enter underline mode (used for underlined text)
    LESS_TERMCAP_us: $'(ansi gb)'
    # exit underline mode
    LESS_TERMCAP_ue: $'(ansi reset)'
  } {
    man ($section|"") $page ...$rest
  }
}

def "nu-complete pages" [] {
  {
    options: {
      case_sensitive: false,
      completion_algorithm: fuzzy, # fuzzy or prefix
      positional: false,
      sort: true,
    },
    completions: ( apropos . | parse --regex '^(?P<value>.*?)\s+.*?- (?P<description>.*?)$' )
  }
}

def "nu-complete sections" [] {
  [
    [value description];
    [1   "Executable programs or shell commands"]
    [2   "System calls (functions provided by the kernel)"]
    [3   "Library calls (functions within program libraries)"]
    [4   "Special files (usually found in /dev)"]
    [5   "File formats and conventions, e.g. /etc/passwd"]
    [6   "Games"]
    [7   "Miscellaneous (including macro packages and conventions), e.g. man(7), groff(7), man-pages(7)"]
    [8   "System administration commands (usually only for root)"]
    [9   "Kernel routines [Non standard]"]
  ]
}
