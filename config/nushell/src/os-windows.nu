# Windows
# chcp 65001
# export alias vim = "c:/tools/vim/vim90/vim.exe"

# https://github.com/winsiderss/systeminformer
# http://www.windbg.xyz/windbg/article/105-Windbg---Display-parameters-whenever-specific-function-is-called
# https://github.com/mmozeiko/wcap small recording util

# export alias sudo = ^gsudo
def "nu-complete sudo-cache-param" [] { [help on off] }
export def "sudo cache" [param: string@"nu-complete sudo-cache-param" ] {
    ^gsudo cache $param
}
def "nu-complete sudo-config-key" [] { gsudo config | parse "# {value}: {description}" }
export def --wrapped "sudo config" [
    key?: string@"nu-complete sudo-config-key"
    value?: string
    --global
    --reset
    ...rest
] {
    ^gsudo config config $key $global $reset ...$rest
}

export module win {
    use broot-helpers.nu *
    # file version and signature viewer from file
    export def "read version" [file: path] {
        ^sigcheck -nobanner $file | lines | skip 1 | parse --regex '\s*(?<name>.+?):(?<value>.+)'
    }


    # File version and signature viewer (see "version of" wrapper")
    #
    # Examples:
    #     sigcheck -nobanner -q -n foo.dll
    #
    # Usage:
    #     sigcheck [-a][-h][-i][-e][-l][-n][[-s]|[-c|-ct]|[-m]][-q][-p <policy GUID>][-r][-u][-vt][-v[r][s]][-f catalog file] [-w file] <file or directory>
    #     sigcheck -d [-c|-ct] [-w file] <file or directory>
    #     sigcheck -o [-vt][-v[r]] [-w file] <sigcheck csv file>
    #     sigcheck -t[u][v] [-i] [-c|-ct] [-w file] <certificate store name|*>
    export extern "sigcheck" [
        ...args: any
        -a    # Show extended version information. The entropy measure reported
              # is the bits per byte of information of the file's contents.
        -c    # CSV output with comma delimiter
        --ct  # CSV output with tab delimiter Specify -nobanner to avoid banner being output to CSV
        -d    # Dump contents of a catalog file
        -e    # Scan executable images only (regardless of their extension)
        -f    # Look for signature in the specified catalog file
        -h    # Show file hashes
        -i    # Show catalog name and signing chain
        -l    # Traverse symbolic links and directory junctions
        -m    # Dump manifest
        -n    # Only show file version number
        -o    # Performs Virus Total lookups of hashes captured in a CSV
              #    file previously captured by Sigcheck when using the -h option.
              #    This usage is intended for scans of offline systems.
        -p    # Verify signatures against the specified policy, represented by
        #             its GUID, or the custom code integrity policy stored in the specified
        #             policy file.
        -r    # Disable check for certificate revocation
        -s    # Recurse subdirectories
        -t    # Dump contents of specified certificate store ('*' for all stores).
        --tu    # Dump contents of specified certificate store ('*' for all stores).
                # Query the user store (machine store is the default)
        --tuv   # Dump contents of specified certificate store ('*' for all stores).
                # Query the user store (machine store is the default)
                #    Append '-v' to have Sigcheck download the trusted Microsoft
                #    root certificate list and only output valid certificates not rooted to
                #    a certificate on that list. If the site is not accessible,
                #    authrootstl.cab or authroot.stl in the current directory are
                #    used instead, if present.
        -u      # If VirusTotal check is enabled, show files that are unknown by VirusTotal or have non-zero detection, otherwise show only unsigned files.
        #   -v[rs]  Query VirusTotal (www.virustotal.com) for malware based on file hash.
        #           Add 'r' to open reports for files with non-zero detection. Files
        #           reported as not previously scanned will be uploaded to VirusTotal
        #           if the 's' option is specified. Note scan results may not be
        #           available for five or more minutes.
        #   -vt     Before using VirusTotal features, you must accept
        #           VirusTotal terms of service. See:
        #
        #           https://www.virustotal.com/en/about/terms-of-service/
        #
        #           If you haven't accepted the terms and you omit this
        #           option, you will be interactively prompted.
        #   -w      Writes the output to the specified file.
        --nobanner  # Do not display the startup banner and copyright message.
    ]

    # application for CPU spikes, unhandled exception and hung window monitoring cli tool
    #
    # https://learn.microsoft.com/en-us/sysinternals/downloads/procdump#using-procdump
    #
    # Examples:
    #   Wait for App to start and create mem dump if it crashes
    #   procdump -accepteula -ma -e -w Max.exe c:\dumps
    #
    #   Install ProcDump as the (AeDebug) postmortem debugger:
    #   procdump -accepteula -ma -i c:\dumps
    #
    #   Uninstall ProcDump as the (AeDebug) postmortem debugger:
    #   procdump -u
    export extern "procdump" [ ...args: any ]
    export def "procdump postmortem-debugger install" [] { ^procdump -accepteula -ma -i c:\dumps }
    export def "procdump postmortem-debugger uninstall" [] { ^procdump -u }

    def "nu-complete list-process-names" [] { ps | get name | sort | uniq }

    #   Watches app for crashes
    export def "procdump watch" [
        app: string@"nu-complete list-process-names"
        --and-open
    ] {
        loop {
            try {^procdump -accepteula -ma -e -w $app c:\dumps}
            if $and_open { open last dump }

        }
    }


    # https://stackoverflow.com/questions/8560166/silent-installation-of-a-msi-package
    export def "msi silent-install" [msi_file: path] {
        # wmic product get name
        # msiexec /i c:\path\to\package.msi /quiet /qn /norestart /log c:\path\to\install.log PROPERTY1=value1 PROPERTY2=value2
        let $logfile = $"($msi_file | path basename).XXXX.log"
        let $logfile = (mktemp $logfile)
        print $"Installing ($msi_file) see log at ($logfile)"
        msiexec.exe /i $msi_file /QN /L*V $logfile
    }

    def "nu-complete installed-pkgs" [] {
        ( open /tmp/installed-pkgs.txt | lines
            | each { $in | str trim }
            | where {not ($in | is-empty) } )
    }

    export def "msi refresh-list" [] { wmic product get name | save -f /tmp/installed-pkgs.txt }

    export def "msi uninstall" [
        pkg: string@"nu-complete installed-pkgs"  # call `msi refresh-list` if you feel not up to date
    ] {
        # example
        print wmic Product Where "Name='Max 8 (64-bit)'" Call Uninstall /NoInteractive
    }

    # open in visual studio
    export def "open in visual-studio" [file: path] {
        let vswhere = $'($env."ProgramFiles(x86)")\Microsoft Visual Studio\Installer\vswhere.exe'
        if not ($vswhere | path exists) {
            error make {msg: $"($vswhere) not found" }
        }

        # https://github.com/microsoft/vswhere/wiki/Find-VC
        let latest = ^$vswhere -latest | parse "{property}: {value}"
        let installation_path = $latest | transpose --header-row | get installationPath.0
        let vs = $'($installation_path)\Common7\IDE\devenv.exe'
        if not ($vs | path exists) {
            error make {msg: $"($vs) not found" }
        }

        run-external $vs /Edit ($file | path expand)
    }

    def "nu-complete procs" [] { ps | select pid name | sort-by name | rename -c { pid: value, name: description } }

    export def "windbg attach-to-process" [ --pid(-p): int@"nu-complete procs" ] {
        let windbg = '~/AppData/Local/Microsoft/WindowsApps/WinDbgX.exe'
        if (not ($windbg | path exists)) {
            error make {msg: $"($windbg) not found, please edit 'windbg attach-to-process' function in ($env.CURRENT_FILE)" }
        }
        run-external $windbg "-p" $pid
    }

    export def "windbg" [ ...args: any ] {
        ~/AppData/Local/Microsoft/WindowsApps/WinDbgX.exe ...$args
    }


    export def "open last dump" [] { start (ls ('/dumps' | path expand) | sort-by modified | last | get name) }

    # https://lldb.llvm.org/use/tutorial.html, `br set -n myfunction` , wa set var ret
    export def "lldb attach-to-process" [process_name: string = "", processid: int = 0] {
        let processid = if $process_name != "" {
            ps | where name =~ $"\(?i\)($process_name)" | get pid.0
        } else {
            if $processid == 0 {  ps | input list -d name --fuzzy  | get pid } else { $processid }
        }

        let python_dir = (py -3.10 -c "import sys; print(sys.base_exec_prefix)")
        print $"(ansi purple_bold)pythond_dir ($python_dir)(ansi reset)"

        with-env {Path: ($env.Path | prepend $python_dir) ,PYTHONHOME: $python_dir, PYTHONPATH: $"($python_dir)/Lib"} {
            python --version
            lldb -p $processid
        }
    }

    export def --wrapped "cargo test-windbg" [ ...cargo_test_args: string ] {
        let executable = (cargo t ...$cargo_test_args --no-run e>| parse --regex 'Executable.*\((?<name>.+)\)' | get 0.name)
        open-in-windbg $executable
    }

    export alias "open timeline" = start http://localhost:5600/#/timeline
    export alias "open music" = ^"/Program Files/VideoLAN/VLC/vlc.exe" ~/Music

    export def "open last screen-shot" [] { start (ls ('~/Pictures/Screenshots' | path expand) | sort-by modified | last | get name) }
    export def "open last screen-recording" [] { start (ls ('~/Videos/Screen Recordings' | path expand) | sort-by modified | last | get name) }

    export def "screen recordings to gif" [] {
        ( ls `~/Videos/Screen Recordings/*mp4` | get name | path parse
            | where {|x| not ($x.parent | path join $'($x.stem).gif' | path exists) }
            | par-each { |el| ffmpeg -i ($el.parent | path join $'($el.stem).($el.extension)') $"($el.parent | path join $el.stem).gif"} )

        start ('~/Videos/Screen Recordings' | path expand)
    }

    def "nu-complete proc-names" [] { ps | get name | uniq }

    def "nu-complete ps-priority" [] { [ [value description]; [3 High] [6 'Above Normal'] [2 Normal] [5 'Below Normal'] [1 Low] ] }

    # permanently set priority for process in windows registry
    export def "ps set-permanent-priority" [
        proc_name: string@"nu-complete proc-names"
        --cpu-priority: int@"nu-complete ps-priority" = 2
        --io-priority: int@"nu-complete ps-priority" = 2
    ] {
        if not (is-admin) { error make {msg: $"(ansi rb)You need admin rights(ansi reset)" } }
        # https://answers.microsoft.com/en-us/windows/forum/all/how-to-permanently-set-priority-processes-using/2f9ec439-5333-4625-9577-69d322cfbc5e
        let perf_options_path = $'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\($proc_name)\PerfOptions'
        reg add $perf_options_path /v CpuPriorityClass /t REG_DWORD /d $cpu_priority
        reg add $perf_options_path /v IoPriority /t REG_DWORD /d $io_priority
    }

    # permanently remap Caps Lock as Esc
    export def "remap caps-lock-esc" [] {
        if not (is-admin) { error make {msg: $"(ansi rb)You need admin rights(ansi reset)" } }
        let key = 'HKLM\System\CurrentControlSet\Control\Keyboard Layout\'
        let data = ['00' '00' '00' '00' '00' '00' '00' '00' '02' '00' '00' '00' '01' '00' '3A' '00' '00' '00' '00' '00'] | str join ''
        #                                                    ^^                 -^^---^^---^^---^^-
        # The ['02']: sets how many remaps there will be plus 1. So 01 is 1-remap, (06 would be 5-remaps)
        # The [ '01' '00' '3A' '00' ]: Remaps Caps Lock ('3A' '00') to Esc ('01' '00') where each key is little endian
        reg add $key /v "Scancode Map" /t REG_BINARY /d $data
        print $'(ansi pb)For remap to take effect you need to reboot(ansi reset)'
    }

    # list logical disks somehing akin to unix's df command
    export def "disk free" [] {
        (wmic logicaldisk get deviceid,size,freespace,volumename,description | str trim
            | detect columns
            | insert Use% { 100 - ($in.freespace|into int) / ($in.size|into int) * 100 }
            | move Use% --after DeviceID
        )
    }

    # unix's lsof like but in windows, a wrapper for handle https://learn.microsoft.com/en-us/sysinternals/downloads/handle
    export def --wrapped lsof [...rest] {
        handle ...$rest
    }

    export def "clean downloads" [] {
        cd ~/Downloads
        let files = ls
        print $files
        if ((input --numchar 1 $"(ansi pb)Shall I delete those files [y/n]?(ansi reset)" | str downcase) == 'y') {
            rm -rf ~/Downloads/*
        }
    }

    export def "which all-dumpbin" [] { vswhere -latest -find **/dumpbin.exe | str replace -a '\\' '/' }

    # copy to clipboard install basic software, useful when asked to do support on other machines
    export def "copy debug-session-software" [] { echo "winget install --silent BurntSushi.ripgrep.MSVC sharkdp.fd dystroy.broot TomHudson.gron" | clip }

    export def "outlook new-mail" [
        to: string,
        subject: string,
        --attach(-a): path,
        --body(-b): string = "",
    ] {
        let outlook_path = 'C:/Program Files/Microsoft Office/root/Office16/OUTLOOK.EXE'
        # let outlook_path = '~\AppData\Local\Microsoft\WindowsApps\olk.exe' | path expand

        ( run-external $outlook_path
            /c ipm.note
            /m $"($to)?subject=($subject)&body=($body)"
            ...(if $attach != null {  ['/a' ($attach | path expand)] } ) )
    }

}

