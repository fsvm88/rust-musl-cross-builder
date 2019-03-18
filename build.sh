#!/bin/bash

SCRIPT_DIR=$(pwd)
TMP_DIR="$HOME/tmp-rust-musl-cross-builder"
VANILLA=1
INVALIDATED=0
export RUST_BACKTRACE=1

function test_output() {
    [ "$1" -ne 0 ] \
        && echo "ERROR: $2" \
        && exit $3
}

[ -z "$MAKEOPTS" ] && MAKEOPTS="-j1"

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
    test_output "$?" "failed building musl-cross-make" "5"

    sudo make install
    test_output "$?" "failed installing musl-cross-make" "6"

    touch .installed
    INVALIDATED=1
else
    echo "====================== musl-cross-make was already built and installed, if you want to rebuild with different config remove: $TMP_DIR/musl-cross-make/.installed"
fi
popd
echo "---------------- END CROSS-ENV STAGE" 

echo "---------------- RUST STAGE"
[[ "$MAKEOPTS" =~ "--silent" ]] && MAKEOPTS="${MAKEOPTS/--silent/}"
if [ $VANILLA -eq 1 ]; then
    echo "====================== Running with rust-vanilla"
    [ ! -d "rust-vanilla" ] \
        && git clone https://github.com/rust-lang/rust.git rust-vanilla \
        && cd rust-vanilla \
        && git checkout -f 1.32.0 \
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
        ./x.py clean
        echo "====================== rust-vanilla was never built, rerunning"
        echo "++++++++++++++++++++++++ PATCHING"
        for a in $SCRIPT_DIR/vanilla-patches/*; do
            patch --quiet -N --dry-run -p1 < "$a"
            [[ $? -eq 1 ]] && echo "====================== Skipping patch (already applied or failing): $a" && continue
            echo "====================== Applying patch: $a"
            patch -p1 < "$a"
            test_output "$?" "tried to apply non-applied patch after dry-run, but got error!" "7"
        done
        echo "++++++++++++++++++++++++ END PATCHING (sleeping 10 seconds to allow checking of output)"
        sleep 10

        cp $SCRIPT_DIR/config-vanilla.toml ./config.toml

        ./x.py build $MAKEOPTS \
            --exclude src/tools/miri
        test_output "$?" "failed building rust, aborting!" "8"
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
        test_output "$?" "failed dist'ing rust, aborting!" "9"
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
