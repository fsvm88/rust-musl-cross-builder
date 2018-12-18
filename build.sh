#!/bin/bash

SCRIPT_DIR=$(pwd)
TMP_DIR="$HOME/tmp-rust-musl-cross-builder"
VANILLA=1

mkdir -p $TMP_DIR
[ ! -d $TMP_DIR ] \
    && echo "TMP_DIR ($TMP_DIR) does not exist or is not a directory, bailing out!" \
    && exit 23
echo "---------------- Running in TMP_DIR: $TMP_DIR"
cd $TMP_DIR
echo "---------------- CROSS-ENV STAGE" 
[ ! -d "musl-cross-make" ] && git clone https://github.com/richfelker/musl-cross-make.git
pushd musl-cross-make

git pull
git checkout -f

cp $SCRIPT_DIR/config.mak .

make $MAKEOPTS

sudo make install

popd
echo "---------------- END CROSS-ENV STAGE" 

echo "---------------- RUST STAGE"
if [ $VANILLA -eq 1 ]; then
    [ ! -d "rust-vanilla" ] \
        && git clone https://github.com/rust-lang/rust.git rust-vanilla \
        && cd rust-vanilla \
        && git checkout 1.31.0 \
        && git clean -dfx \
        && git submodule init . \
        && git submodule update -f \
        && git clean -dfx \
        && cd ..
    pushd rust-vanilla

    # Even if we already cloned, reset the working tree and reapply patches
    # git checkout -f 1.31.0
    # git submodule update -f
    echo "++++++++++++++++++++++++ PATCHING"
    for a in $SCRIPT_DIR/vanilla-patches/*; do
        patch --quiet -N --dry-run -p1 < "$a"
        [[ $? -eq 1 ]] && echo "====================== Skipping patch (already applied or failing): $a" && continue
        echo "Applying patch: $a"
        patch -p1 < "$a"
    done
    echo "++++++++++++++++++++++++ END PATCHING"

    cp $SCRIPT_DIR/config-vanilla.toml ./config.toml

    ./x.py build \
        --exclude src/tools/miri

    popd
else
    [ ! -d "rust" ] \
        && git clone https://github.com/smaeul/rust.git \
        && cd rust \
        && git submodule init \
        && git submodule update -f \
        && git checkout bootstrap-1.30.1 \
        && git clean -dfx \
        && git checkout -f bootstrap-1.30.1 \
        && git submodule update -f \
        && cd ..
    pushd rust

    cp $SCRIPT_DIR/config.toml .

    ./x.py build \
        --exclude src/tools/miri

    popd
fi
echo "---------------- END RUST STAGE" 
