export def "cargo super-fix" [] {
  cargo fmt --all
  cargo fix --allow-dirty --allow-staged
  cargo clippy --fix --allow-dirty --allow-staged
}

# rustup override set stable


export def --wrapped "rust proc-macro expand" [...rest ] { cargo expand ...$rest }
export def --wrapped "rust proc-macro backtrace" [...rest ] { RUSTFLAGS="-Z proc-macro-backtrace" cargo +nightly ...$rest }

export alias 'rust add-cheap-trace' = ast-grep scan --inline-rules '
   id: add-trace
   language: rust
   rule:
     pattern: "{ $$$BODY }"
     inside:
       kind: function_item
       has:
         field: name
         pattern: $FUNC
   fix: |-
     {
         eprintln!("[calling] $FUNC");
         $$$BODY
     }
' -U
