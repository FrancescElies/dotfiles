# list available wibu executables
export def "wibu ls-bin" [] {
 [
   (ls `/Program Files/WIBU-SYSTEMS/AxProtector/Devkit/bin/*exe`)
   (ls `/Program Files/CodeMeter/DevKit/bin/*exe` )
 ] | flatten | get name | each {$in | path expand }
}

