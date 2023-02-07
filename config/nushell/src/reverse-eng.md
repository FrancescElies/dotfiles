# Radare2
https://rada.re/n/radare2.html
https://www.radare.org/advent/07.html
https://github.com/ifding/radare2-tutorial

https://github.com/pgosar/ChatGDB
https://github.com/bootleg/ret-sync
https://github.com/DerekSelander/LLDB
https://github.com/snare/voltron/wiki/Installation
https://github.com/foundryzero/llef

```
# ~/.radare2rc

# > :ed                 # edit ~/.radare2rc
# > :e??  > options.txt # save options to file

e bin.relocs.apply=true     # apply reloc information
e scr.interactive = true    # start in interactive mode
e asm.pseudo = true         # enable pseudo syntax
e cfg.fortunes = true       # tips at startup
e cmd.stack = true          # display the stack in visual debug mode
e scr.utf8 = true           # show UTF-8 characters instead of ANSI
e asm.describe = true       # show opcode description
e asm.cmt.right=true        # show comments at right

```

## Attacks 
typical exploitable c problems buffer overflow, stack smashing, return oriented
programming.

## usage
cli
```
$ rasm2 -a arm -b 32 -d `rasm2 -a arm -b 32 nop`
$ rabin2 -Ss /bin/ls  # list symbols and sections
$ rahash2 -a md5 /bin/ls
$ rafind2 -x deadbeef bin
```
Some common commands
```
$ r2 /bin/ls
> a?     # add ? to get help for any command
> f?     # flags
> $?     # variables
> y?     # clipboard
> aaa    # analyze all the things
> is     # list symbols
> ii     # list imported symbols
> iE     # list exported symbols
> ie     # list exported symbols
> ie     # list exported symbols
> afl    # list functions found
> pdf    # disassemble function, e.g. pdf @ sym.main
> s <tab># seek to address
> v      # enter visual panels mode
> p      # cycle modes visual modes (visual mode)
> ood    # reload program

> dp # debug process (attach, list ...)
> axt sym.imp.printf # find references to a function
```

## plugins
```
$ r2pm -U # init or update database (-f clean clone)
# sudo dnf install zlib-devel patch
$ r2pm -ci r2ghidra r2dec r2frida
```

## frida
Type short commands instead of writing javascript
```
$ r2 frida:///bin/ls
> :dc         # continue the execution
> :dcu        # continue the execution until
> :dd         # list file descriptors
> :dm         # show process memory maps
> :dmm        # show modules mapped
> :dl foo.so  # load a shlib
> :dt write   # trace every call to 'write'
> :isa read   # find where's the read symbol located
> :ii         # list imports off the current module
> :dxc exit 0 # call 'exit' symbol with argument 0
```

## debugger
```
$ r2 -d gdb://127.0.0.1
> ds          # step into
> dso         # step over
> dr=         # show registers in columns
> dbt         # show backtrace
> dsu entry0  # continue until entrypoint
> dr rax=33   # change value of register
> pxr@rsp     # inspect stack
> drr         # periscoped register values
> S           # step over

```

## docs
```
r2 -Qc'?*~...' --
```
