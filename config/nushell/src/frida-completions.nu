def get_device_arguments [] {
    let tokens = $nu.env.COMMAND_LINE? | split row ' ' | compact
    let device_argument_flags = ["-D" "--device" "-H" "--host" "--certificate" "--origin" "--token" "--stun-server" "--relay"]
    let device_flags = ["-U" "--usb" "-R" "--remote" "--p2p"]

    $tokens | each --index { |token, idx|
        if ($token in $device_argument_flags) {
            print $token
            if ($token !~ "=") {
                if ($idx + 1) < ($tokens | length) {
                    print $tokens | get ($idx + 1)
                }
            }
        } else if ($token in $device_flags) {
            print $token
        }
    }
}

def get_device_processes [] {
    let relevant_flags = (get_device_arguments | str join ' ')

    (^frida-ps ...($relevant_flags | split row ' ') 2>/dev/null
        | lines
        | skip 2
        | each { |line|
            let parts = ($line | split column -r '\s+')
            {pid: ($parts | get 0.column1), name: ($parts | get 0.column2)}
        }
        | sort-by pid)
}

def get_device_pids [] {
    let relevant_flags = (get_device_arguments | str join ' ')

    (^frida-ps ...($relevant_flags | split row ' ') 2>/dev/null
        | lines
        | skip 2
        | each { |line|
            let parts = ($line | split column -r '\s+')
            $parts | get 0.column1
        }
        | sort-by { into int })
}

def get_device_processes_names [] {
    let relevant_flags = (get_device_arguments | str join ' ')

    (^frida-ps ...($relevant_flags | split row ' ') 2>/dev/null
        | lines
        | skip 2
        | each { |line|
            let parts = ($line | split column -r '\s+')
            $parts | get 0.column2
        }
        | sort)
}

def get_device_identifiers [] {
    let relevant_flags = (get_device_arguments | str join ' ')

    (^frida-ps --applications ...($relevant_flags | split row ' ') 2>/dev/null
        | lines
        | skip 2
        | each { |line|
            let parts = ($line | split column -r '\s+')
            $parts | get 0.column3
        }
        | sort)
}

def get_frida_devices [] {
    (^frida-ls-devices
        | lines
        | skip 2
        | each { |line|
            let parts = ($line | split column -r '\s+' -m 2)
            {id: ($parts | get 0.column1), info: ($parts | get 0.column2)}
        })
}

export extern "frida" [
    # Base arguments
    -O --options-file: string@"nu-complete frida_options_file"    # text file containing additional command line options
    --version                                                     # show program's version number and exit
    -h --help                                                     # show this help message and exit

    # Device arguments
    -D --device: string@"nu-complete frida_devices"            # connect to device with the given ID
    -U --usb                                                   # connect to USB device
    -R --remote                                                # connect to remote frida-server
    -H --host: string                                          # connect to remote frida-server on HOST
    --certificate: path                                        # speak TLS with HOST, expecting CERTIFICATE
    --origin: string                                           # connect to remote server with "Origin" header set to ORIGIN
    --token: string                                            # authenticate with HOST using TOKEN
    --keepalive-interval: string                               # set keepalive interval in seconds
    --p2p                                                      # establish a peer-to-peer connection with target
    --stun-server: string                                      # set STUN server ADDRESS to use with --p2p
    --relay: string                                            # add relay to use with --p2p

    # Target arguments
    -f --file: path                                                   # Spawn FILE
    -F --attach-frontmost                                             # attach to frontmost application
    -n --attach-name: string@"nu-complete frida_process_names"        # attach to NAME
    -N --attach-identifier: string@"nu-complete frida_identifiers"    # attach to IDENTIFIER
    -p --attach-pid: string@"nu-complete frida_pids"                  # attach to PID
    -W --await: string                                                # await spawn matching PATTERN
    --stdio: string                                                   # stdio behavior when spawning (inherit/pipe)
    --aux: string                                                     # set aux option when spawning
    --realm: string                                                   # realm to attach in (native/emulated)
    --runtime: string                                                 # script runtime to use (qjs/v8)
    --debug                                                           # enable the Node.js compatible script debugger
    --squelch-crash                                                   # if enabled, will not dump crash report to console

    # Frida specific
    -l --load: path                                # load SCRIPT
    -P --parameters: string                        # parameters as JSON, same as Gadget
    -C --cmodule: string                           # load CMODULE
    --toolchain: string                            # CModule toolchain to use (any/internal/external)
    -c --codeshare: string                         # load CODESHARE_URI
    -e --eval: string                              # evaluate CODE
    -q                                             # quiet mode (no prompt) and quit after -l and -e
    -t --timeout: string                           # seconds to wait before terminating in quiet mode
    --pause                                        # leave main thread paused after spawning program
    -o --output: path                              # output to log file
    --eternalize                                   # eternalize the script before exit
    --exit-on-error                                # exit with code 1 after encountering any exception
    --auto-perform                                 # wrap entered code with Java.perform
    --auto-reload                                  # Enable auto reload of provided scripts and c module
    --no-auto-reload                               # Disable auto reload of provided scripts and c module
]

export extern "frida-ls-devices" [
    -O --options-file: string  # text file containing additional command line options
    --version                  # show program's version number and exit
    -h --help                  # show this help message and exit
]

export extern "frida-ps" [
    -O --options-file: string  # text file containing additional command line options
    --version                  # show program's version number and exit
    -h --help                  # show this help message and exit

    -D --device: string@"nu-complete frida_devices"            # connect to device with the given ID
    -U --usb                                                   # connect to USB device
    -R --remote                                                # connect to remote frida-server
    -H --host: string                                          # connect to remote frida-server on HOST

    -a --applications                        # list only applications
    -i --installed                            # include all installed applications
    -j --json                            # output results as JSON
]

export extern "frida-kill" [
    -O --options-file: string                    # text file containing additional command line options
    --version                            # show program's version number and exit
    -h --help                            # show this help message and exit

    -D --device: string@"nu-complete frida_devices"            # connect to device with the given ID
    -U --usb                            # connect to USB device
    -R --remote                            # connect to remote frida-server
    -H --host: string                        # connect to remote frida-server on HOST
]

export extern "frida-discover" [
    -O --options-file: string                    # text file containing additional command line options
    --version                            # show program's version number and exit
    -h --help                            # show this help message and exit

    # Device and target arguments (abbreviated for brevity)
    -D --device: string@"nu-complete frida_devices"
    -p --attach-pid: string@"nu-complete frida_pids"
]

export extern "frida-trace" [
    -O --options-file: string                    # text file containing additional command line options
    --version                            # show program's version number and exit
    -h --help                            # show this help message and exit

    -D --device: string@"nu-complete frida_devices"            # connect to device
    -p --attach-pid: string@"nu-complete frida_pids"        # attach to PID

    -I --include-module: string                        # include MODULE
    -X --exclude-module: string                        # exclude MODULE
    -i --include: string                               # include [MODULE!]FUNCTION
    -x --exclude: string                               # exclude [MODULE!]FUNCTION
    -a --add: string                                   # add MODULE!OFFSET
    -T --include-imports                               # include program's imports
    -t --include-module-imports: string                # include MODULE imports
    -m --include-objc-method: string                   # include OBJC_METHOD
    -M --exclude-objc-method: string                   # exclude OBJC_METHOD
    -j --include-java-method: string                   # include JAVA_METHOD
    -J --exclude-java-method: string                   # exclude JAVA_METHOD
    -s --include-debug-symbol: string                  # include DEBUG_SYMBOL
    -q --quiet                                         # do not format output messages
    -d --decorate                                      # add module name to generated onEnter log statement
    -S --init-session: path                            # path to JavaScript file used to initialize the session
    -P --parameters: string                            # parameters as JSON
    -o --output: path                                  # dump messages to file
]

export extern "frida-join" [
    -O --options-file: string                    # text file containing additional command line options
    --version                            # show program's version number and exit
    -h --help                            # show this help message and exit

    -D --device: string@"nu-complete frida_devices"
    -p --attach-pid: string@"nu-complete frida_pids"
    --portal-location: string                    # join portal at LOCATION
    --portal-certificate: path                    # speak TLS with portal expecting CERTIFICATE
    --portal-token: string                        # authenticate with portal using TOKEN
    --portal-acl-allow: string                    # limit portal access to control channels with TAG
]

export extern "frida-create" [
    -O --options-file: string                    # text file containing additional command line options
    --version                            # show program's version number and exit
    -h --help                            # show this help message and exit

    -n --project-name: string                    # project name
    -o --output-directory: path                    # output directory
    -t: string                            # template file
]

export extern "frida-apk" [
    -O --options-file: string                    # text file containing additional command line options
    --version                            # show program's version number and exit
    -h --help                            # show this help message and exit

    -o --output: path                        # output path
    -g --gadget: path                        # inject the specified gadget library
    -c --gadget-config: string                    # set the given key=value gadget interaction config
]

export extern "frida-compile" [
    -O --options-file: string                    # text file containing additional command line options
    --version                            # show program's version number and exit
    -h --help                            # show this help message and exit

    -o --output: path                        # write output to <file>
    -w --watch                            # watch for changes and recompile
    -S --no-source-maps                        # omit source-maps
    -c --compress                            # compress using terser
    -v --verbose                            # be verbose
]

# Completion providers
def "nu-complete frida_devices" [] {
    get_frida_devices | each { |device| {value: $device.id, description: $device.info} }
}

def "nu-complete frida_pids" [] {
    get_device_pids | each { |pid| {value: $pid, description: $pid} }
}

def "nu-complete frida_process_names" [] {
    get_device_processes_names | each { |name| {value: $name, description: $name} }
}

def "nu-complete frida_identifiers" [] {
    get_device_identifiers | each { |id| {value: $id, description: $id} }
}

def "nu-complete frida_options_file" [] {
    # File completion - let the default file completer handle this
    []
}
