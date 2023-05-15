#!/bin/bash
echo "working dir:"
pwd

export PATH=$PATH:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin

export CARGO_HOME=/mnt/ext/etc/.cargo
PATH=$PATH:$CARGO_HOME/bin

export RUSTUP_HOME=/mnt/ext/etc/.rustup
PATH=$PATH:$RUSTUP_HOME

export RUST_SRC_PATH=/mnt/ext/etc/projects/rust_projects/rust/src
PATH=$PATH:$RUST_SRC_PATH

rustup override set nightly
rustup target add x86_64-unknown-linux-gnu

cargo -Z unstable-options -C $1 build --release

cp $1/output/x86_64-unknown-linux-gnu/release/*.a $1/librustshims.a
