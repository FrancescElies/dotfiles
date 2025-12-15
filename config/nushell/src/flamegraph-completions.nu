const examples = '
# if you would like to profile an arbitrary executable:
flamegraph [-o my_flamegraph.svg] -- /path/to/my/binary --my-arg 5

# or if the executable is already running, you can provide the PID via `-p` (or `--pid`) flag:
flamegraph [-o my_flamegraph.svg] --pid 1337

# NOTE: By default, perf tries to compute which functions are
# inlined at every stack frame for every sample. This can take
# a very long time (see https://github.com/flamegraph-rs/flamegraph/issues/74).
# If you do not want this, you can pass --no-inline to flamegraph:
flamegraph --no-inline [-o my_flamegraph.svg] /path/to/my/binary --my-arg 5

# cargo support provided through the cargo-flamegraph binary!
# defaults to profiling cargo run --release
cargo flamegraph

# by default, `--release` profile is used,
# but you can override this:
cargo flamegraph --dev

# if you would like to profile a specific binary:
cargo flamegraph --bin=stress2

# if you want to pass arguments as you would with cargo run:
cargo flamegraph -- my-command --my-arg my-value -m -f

# if you want to use interesting perf or dtrace options, use `-c`
# this is handy for correlating things like branch-misses, cache-misses,
# or anything else available via `perf list` or dtrace for your system
cargo flamegraph -c "record -e branch-misses -c 100 --call-graph lbr -g"

# Run criterion benchmark
# Note that the last --bench is required for `criterion 0.3` to run in benchmark mode, instead of test mode.
cargo flamegraph --bench some_benchmark --features some_features -- --bench

cargo flamegraph --example some_example --features some_features

# Profile unit tests.
# Note that a separating `--` is necessary if `--unit-test` is the last flag.
cargo flamegraph --unit-test -- test::in::package::with::single::crate
cargo flamegraph --unit-test crate_name -- test::in::package::with::multiple:crate
cargo flamegraph --unit-test --dev test::may::omit::separator::if::unit::test::flag::not::last::flag

# Profile integration tests.
cargo flamegraph --test test_name
'

export def "flamegraph examples" [] {
    echo $examples | nvim
}
