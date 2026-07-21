Build it

    git clone clone https://github.com/ililim/dual-key-remap
    cd dual-key-remap
    zig rc resources.rc
    zig build-exe ./dual-key-remap.c ./resources.res -target x86_64-windows-gnu -lc -luser32 -lshell32 --subsystem windows
    cp ~/src/dotfiles/config/dual-remap/config.txt .
    add-to-startup.bat

Uninstall it

      schtasks /delete /tn "DualKeyRemap" /f
