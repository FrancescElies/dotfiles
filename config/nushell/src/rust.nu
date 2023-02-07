export def "cargo super-fix" [] {
  cargo fmt --all
  cargo fix --allow-dirty --allow-staged
  cargo clippy --fix --allow-dirty --allow-staged
}

# rustup override set stable


export def --wrapped "rust proc-macro expand" [...rest ] { cargo expand ...$rest }
export def --wrapped "rust proc-macro backtrace" [...rest ] { RUSTFLAGS="-Z proc-macro-backtrace" cargo +nightly ...$rest }
