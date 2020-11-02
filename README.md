# build-static-tmux

A script or building a static tmux for linux which should run on a wide selection of distributions (tested on Ubuntu, SLES12)

**Versions**
* [tmux 3.1c](https://github.com/tmux/tmux/)
* [musl 1.2.1](https://www.musl-libc.org/)
* [ncurses 6.2](https://invisible-island.net/ncurses/)
* [libevent 2.1.12](https://github.com/libevent/libevent/)

Binaries available in releases.
Build on Travis-CI (Ubuntu 16.04.6 LTS, x86_64-pc-linux-gnu)
[![Build Status](https://travis-ci.org/mjakob-gh/build-static-tmux.svg?branch=master)](https://travis-ci.org/mjakob-gh/build-static-tmux)

Beware: the upx compressed file will not work on the Windows Subsystem for Linux (WSL), use the stripped Version.
