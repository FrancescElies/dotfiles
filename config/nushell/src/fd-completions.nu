module completions {

  def "nu-complete fd filetype" [] {
    [ "file" "directory" "symlink" "block-device" "char-device" "executable" "empty" "socket" "pipe" ]
  }

  def "nu-complete fd color" [] {
    [ "auto" "always" "never" ]
  }

  def "nu-complete fd hyperlink" [] {
    [ "auto" "always" "never" ]
  }

  def "nu-complete fd strip_cwd_prefix" [] {
    [ "auto" "always" "never" ]
  }

  def "nu-complete fd gen_completions" [] {
    [ "bash" "elvish" "fish" "powershell" "zsh" "nushell" ]
  }

  # A program to find entries in your filesystem
  export extern fd [
    --hidden(-H)              # Search hidden files and directories
    --no-hidden               # Overrides --hidden
    --no-ignore(-I)           # Do not respect .(git|fd)ignore files
    --ignore                  # Overrides --no-ignore
    --no-ignore-vcs           # Do not respect .gitignore files
    --ignore-vcs              # Overrides --no-ignore-vcs
    --no-require-git          # Do not require a git repository to respect gitignores. By default, fd will only respect global gitignore rules, .gitignore rules, and local exclude rules if fd detects that you are searching inside a git repository. This flag allows you to relax this restriction such that fd will respect all git related ignore rules regardless of whether you're searching in a git repository or not
    --require-git             # Overrides --no-require-git
    --no-ignore-parent        # Do not respect .(git|fd)ignore files in parent directories
    --no-global-ignore-file   # Do not respect the global ignore file
    --unrestricted(-u)        # Unrestricted search, alias for '--no-ignore --hidden'
    --case-sensitive(-s)      # Case-sensitive search (default: smart case)
    --ignore-case(-i)         # Case-insensitive search (default: smart case)
    --glob(-g)                # Glob-based search (default: regular expression)
    --regex                   # Regular-expression based search (default)
    --fixed-strings(-F)       # Treat pattern as literal string stead of regex
    --and: string             # Additional search patterns that need to be matched
    --absolute-path(-a)       # Show absolute instead of relative paths
    --relative-path           # Overrides --absolute-path
    --list-details(-l)        # Use a long listing format with file metadata
    --follow(-L)              # Follow symbolic links
    --no-follow               # Overrides --follow
    --full-path(-p)           # Search full abs. path (default: filename only)
    --print0(-0)              # Separate search results by the null character
    --max-depth(-d): string   # Set maximum search depth (default: none)
    --min-depth: string       # Only show search results starting at the given depth.
    --exact-depth: string     # Only show search results at the exact given depth
    --exclude(-E): string     # Exclude entries that match the given glob pattern
    --prune                   # Do not traverse into directories that match the search criteria. If you want to exclude specific directories, use the '--exclude=…' option
    --type(-t): string@"nu-complete fd filetype" # Filter by type: file (f), directory (d/dir), symlink (l), executable (x), empty (e), socket (s), pipe (p), char-device (c), block-device (b)
    --extension(-e): string   # Filter by file extension
    --size(-S): string        # Limit results based on the size of files
    --changed-within: string  # Filter by file modification time (newer than)
    --changed-before: string  # Filter by file modification time (older than)
    --owner(-o): string       # Filter by owning user and/or group
    --format: string          # Print results according to template
    --exec(-x): string        # Execute a command for each search result
    --exec-batch(-X): string  # Execute a command with all search results at once
    --batch-size: string      # Max number of arguments to run as a batch size with -X
    --ignore-file: path       # Add a custom ignore-file in '.gitignore' format
    --color(-c): string@"nu-complete fd color" # When to use colors
    --hyperlink: string@"nu-complete fd hyperlink" # Add hyperlinks to output paths
    --threads(-j): string     # Set number of threads to use for searching & executing (default: number of available CPU cores)
    --max-buffer-time: string # Milliseconds to buffer before streaming search results to console
    --max-results: string     # Limit the number of search results
    -1                        # Limit search to a single result
    --quiet(-q)               # Print nothing, exit code 0 if match found, 1 otherwise
    --show-errors             # Show filesystem errors
    --base-directory: path    # Change current working directory
    pattern?: string          # the search pattern (a regular expression, unless '--glob' is used; optional)
    --path-separator: string  # Set path separator when printing file paths
    ...path: path             # the root directories for the filesystem search (optional)
    --search-path: path       # Provides paths to search as an alternative to the positional <path> argument
    --strip-cwd-prefix: string@"nu-complete fd strip_cwd_prefix" # By default, relative paths are prefixed with './' when -x/--exec, -X/--exec-batch, or -0/--print0 are given, to reduce the risk of a path starting with '-' being treated as a command line option. Use this flag to change this behavior. If this flag is used without a value, it is equivalent to passing "always"
    --one-file-system         # By default, fd will traverse the file system tree as far as other options dictate. With this flag, fd ensures that it does not descend into a different file system than the one it started in. Comparable to the -mount or -xdev filters of find(1)
    --gen-completions: string@"nu-complete fd gen_completions"
    --help(-h)                # Print help (see more with '--help')
    --version(-V)             # Print version
  ]

}

export use completions *
