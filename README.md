# rust-musl-cross-builder

Contains script and default configuration to cross-compile rust for musl and produce a rustc linked to musl that supports generating dylib executables.  
This can then be used to bootstrap another compiler within a dynamically linked musl chroot.  
Tested and working on Gentoo on 18.12.2018, bootstrapping from cross-compiled rust-1.31 and compiling rust-1.31.  
Only "stable" channel was tested.  

* currently, the non-vanilla (smaeul) tree is not working/not tested (this is a bit stale and should not be used anyway)
* currently rust depends on libunwind.a being present for building, one of the patches addresses this
* the ebuild provided has lot of hard-coded variables, but it works; eclasses will need updates before it can be ported back to a "sane" ebuild
    * the ebuild needs FILESDIR (files/), symlink it to the usual gentoo repo (the only used patch is the clippy-sysroot)
    * when compiling **within** the chroot, drop the vanilla-patches in /etc/portage/patches/dev-lang/rust, otherwise the resulting compiler won't be able to produce dylib binaries

## Running the script
1. `sudo` access may be required for the make install part of the cross-toolchain (default install prefix is /usr/local, so make sure that is in the PATH also)
1. `./build.sh`
    * script was not tested with relative paths etc, so just do the sane thing and call it from the repo folder
1. go have a coffee
