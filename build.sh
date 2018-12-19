#!/bin/bash

SCRIPT_DIR=$(pwd)
TMP_DIR="$HOME/tmp-rust-musl-cross-builder"
VANILLA=1
INVALIDATED=0

mkdir -p $TMP_DIR
[ ! -d $TMP_DIR ] \
    && echo "TMP_DIR ($TMP_DIR) does not exist or is not a directory, bailing out!" \
    && exit 23
echo "---------------- Running in TMP_DIR: $TMP_DIR"
cd $TMP_DIR
echo "---------------- CROSS-ENV STAGE"
[ ! -d "musl-cross-make" ] && git clone https://github.com/richfelker/musl-cross-make.git
pushd musl-cross-make
if [[ ! -f .installed || ! -f /usr/local/bin/x86_64-unknown-linux-musl-gcc ]]; then
    git pull
    git checkout -f

    cp $SCRIPT_DIR/config.mak .

    make $MAKEOPTS

    sudo make install

    touch .installed
    INVALIDATED=1
else
    echo "====================== musl-cross-make was already built and installed, if you want to rebuild with different config remove: $TMP_DIR/musl-cross-make/.installed"
fi
popd
echo "---------------- END CROSS-ENV STAGE" 

echo "---------------- RUST STAGE"
if [ $VANILLA -eq 1 ]; then
    echo "====================== Running with rust-vanilla"
    [ ! -d "rust-vanilla" ] \
        && git clone https://github.com/rust-lang/rust.git rust-vanilla \
        && cd rust-vanilla \
        && git checkout -f 1.31.0 \
        && git clean -dfx \
        && git submodule update -f --init --recursive \
        && cd .. \
        && echo "====================== Cloned and checked out rust-vanilla folder"
    pushd rust-vanilla

    if [ $INVALIDATED -eq 1 ]; then
        echo "====================== Prebuilt stuff was invalidated by new musl-cross-make, removing skipfiles (.built, .dist)"
        rm -f .built .dist
    fi
    if [ ! -f .built ]; then
        echo "====================== rust-vanilla was never built, rerunning"
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
        touch .built
        INVALIDATED=1
    else
        echo "====================== rust-vanilla was already built, if you want to rebuild with different config remove: $TMP_DIR/rust-vanilla/.built"
    fi

    if [ $INVALIDATED -eq 1 ]; then
        echo "====================== Prebuilt stuff was invalidated by new build removing skipfile (.dist)"
        rm -f .dist
    fi
    if [ ! -f .dist ]; then
        ./x.py dist
        touch .dist
    else
        echo "====================== rust-vanilla was already packaged, if you want to repackage with different config remove: $TMP_DIR/rust-vanilla/.dist"
    fi

    popd
else
    echo "====================== Running with rust-smaeul"
    [ ! -d "rust" ] \
        && git clone https://github.com/smaeul/rust.git \
        && cd rust \
        && git submodule init \
        && git submodule update -f \
        && git checkout bootstrap-1.30.1 \
        && git clean -dfx \
        && git submodule update -f --init --recursive \
        && cd ..
    pushd rust

    cp $SCRIPT_DIR/config.toml .

    ./x.py build \
        --exclude src/tools/miri

    ./x.py dist

    popd
fi
echo "---------------- END RUST STAGE" 
