module completions {

  # A command-line utility for easily compressing and decompressing files and directories.
  export extern ouch [
    --yes(-y)                 # Skip [Y/n] questions, default to yes
    --no(-n)                  # Skip [Y/n] questions, default to no
    --accessible(-A)          # Activate accessibility mode, reducing visual noise
    --hidden(-H)              # Ignore hidden files
    --quiet(-q)               # Silence output
    --gitignore(-g)           # Ignore files matched by git's ignore files
    --format(-f): string      # Specify the format of the archive
    --password(-p): string    # Decompress or list with password
    --threads(-c): string     # Concurrent working threads
    --help(-h)                # Print help (see more with '--help')
    --version(-V)             # Print version
  ]

  # Compress one or more files into one output file
  export extern "ouch compress" [
    ...files: path            # Files to be compressed
    output: path              # The resulting file. Its extensions can be used to specify the compression formats
    --level(-l): string       # Compression level, applied to all formats
    --fast                    # Fastest compression level possible, conflicts with --level and --slow
    --slow                    # Slowest (and best) compression level possible, conflicts with --level and --fast
    --follow-symlinks(-S)     # Archive target files instead of storing symlinks (supported by `tar` and `zip`)
    --yes(-y)                 # Skip [Y/n] questions, default to yes
    --no(-n)                  # Skip [Y/n] questions, default to no
    --accessible(-A)          # Activate accessibility mode, reducing visual noise
    --hidden(-H)              # Ignore hidden files
    --quiet(-q)               # Silence output
    --gitignore(-g)           # Ignore files matched by git's ignore files
    --format(-f): string      # Specify the format of the archive
    --password(-p): string    # Decompress or list with password
    --threads(-c): string     # Concurrent working threads
    --help(-h)                # Print help
  ]

  # Decompresses one or more files, optionally into another folder
  export extern "ouch decompress" [
    ...files: path            # Files to be decompressed, or "-" for stdin
    --dir(-d): path           # Place results in a directory other than the current one
    --remove(-r)              # Remove the source file after successful decompression
    --no-smart-unpack         # Disable Smart Unpack
    --yes(-y)                 # Skip [Y/n] questions, default to yes
    --no(-n)                  # Skip [Y/n] questions, default to no
    --accessible(-A)          # Activate accessibility mode, reducing visual noise
    --hidden(-H)              # Ignore hidden files
    --quiet(-q)               # Silence output
    --gitignore(-g)           # Ignore files matched by git's ignore files
    --format(-f): string      # Specify the format of the archive
    --password(-p): string    # Decompress or list with password
    --threads(-c): string     # Concurrent working threads
    --help(-h)                # Print help
  ]

  # List contents of an archive
  export extern "ouch list" [
    ...archives: path         # Archives whose contents should be listed
    --tree(-t)                # Show archive contents as a tree
    --yes(-y)                 # Skip [Y/n] questions, default to yes
    --no(-n)                  # Skip [Y/n] questions, default to no
    --accessible(-A)          # Activate accessibility mode, reducing visual noise
    --hidden(-H)              # Ignore hidden files
    --quiet(-q)               # Silence output
    --gitignore(-g)           # Ignore files matched by git's ignore files
    --format(-f): string      # Specify the format of the archive
    --password(-p): string    # Decompress or list with password
    --threads(-c): string     # Concurrent working threads
    --help(-h)                # Print help
  ]

  # Print this message or the help of the given subcommand(s)
  export extern "ouch help" [
  ]

  # Compress one or more files into one output file
  export extern "ouch help compress" [
  ]

  # Decompresses one or more files, optionally into another folder
  export extern "ouch help decompress" [
  ]

  # List contents of an archive
  export extern "ouch help list" [
  ]

  # Print this message or the help of the given subcommand(s)
  export extern "ouch help help" [
  ]

}

export use completions *
