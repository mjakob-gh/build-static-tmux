#!/usr/bin/env bash

set -eu
set -o pipefail 2>/dev/null || true

export CC=cc
export REALCC=${CC}
export CPPFLAGS="-P"

# ANSI Color Codes
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
COLOR_END="\033[0m"

# Program basename
PGM="${0##*/}"

# Script version
VERSION=3.7b

# How many lines of the error log should be displayed
LOG_LINES=50

# os and processor architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$(uname -m)" in
    aarch64)
        ARCH="arm64"
        ;;
    x86_64)
        ARCH="amd64"
        ;;
    *)
        ARCH="$(uname -m)"
        ;;
esac

TMUX_BIN="tmux.${OS}-${ARCH}"

######################################
###### BEGIN VERSION DEFINITION ######
######################################
TMUX_VERSION=3.7b
MUSL_VERSION=1.2.6
NCURSES_VERSION=6.6
LIBEVENT_VERSION=2.1.13
UPX_VERSION=5.1.1
######################################
####### END VERSION DEFINITION #######
######################################

TMUX_STATIC_HOME="${TMUX_STATIC_HOME:-/tmp/tmux-static}"
LOG_DIR="${TMUX_STATIC_HOME}/log"

TMUX_ARCHIVE="tmux-${TMUX_VERSION}.tar.gz"
TMUX_URL="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}"

MUSL_ARCHIVE="musl-${MUSL_VERSION}.tar.gz"
MUSL_URL="https://musl.libc.org/releases"

NCURSES_ARCHIVE="ncurses-${NCURSES_VERSION}.tar.gz"
NCURSES_URL="https://invisible-island.net/archives/ncurses"

LIBEVENT_ARCHIVE="libevent-${LIBEVENT_VERSION}-stable.tar.gz"
LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable"

UPX_ARCHIVE="upx-${UPX_VERSION}-${ARCH}_${OS}.tar.xz"
UPX_URL="https://github.com/upx/upx/releases/download/v${UPX_VERSION}"

USE_UPX=${USE_UPX:-0}
DUMP_LOG_ON_ERROR=${DUMP_LOG_ON_ERROR:-0}

JOB_COUNT=1
if command -v nproc >/dev/null 2>&1; then
    JOB_COUNT=$(nproc 2>/dev/null || echo 1)
fi

usage_options() {
    printf "\t%b\n" "The following options are available:"
    echo ""
    printf "\t%b\t%s\n" "${BLUE}-c${COLOR_END}" "compress the resulting binary with UPX."
    echo ""
    printf "\t%b\t%s\n" "${BLUE}-d${COLOR_END}" "dump the log of the current build step to stdout if an error occurs."
    echo ""
    printf "\t%b\t%s\n" "${BLUE}-h${COLOR_END}" "print this help message."
    echo ""
}

usage() {
    exec >&2
    echo ""
    echo "NAME"
    printf "\t%b - %s\n" "${BLUE}${PGM}${COLOR_END}" "build a static TMUX binary"
    echo ""
    echo "SYNOPSIS"
    printf "\t%b" "${BLUE}${PGM} [-h | -c -d]${COLOR_END}\n"
    echo ""
    echo "DESCRIPTION"
    usage_options
    echo "ENVIRONMENT"
    printf "\t%b\n" "The following environment variables affect the execution of ${BLUE}${PGM}${COLOR_END}"
    echo ""
    printf "\t%s\t%b\n" "USE_UPX" "set to \"1\" to compress the resulting binary with UPX (see argument ${BLUE}-c${COLOR_END} above)."
    echo ""
    printf "\t%s\t%b\n" "DUMP_LOG_ON_ERROR" "set to \"1\" to dump the log of the current build step to stdout if an error occurs (see argument ${BLUE}-d${COLOR_END} above)."
    echo ""
    printf "\t%s\n" "In case you are behind a proxy, export these environment variables to download the necessary files:"
    printf "\t%s\t%b\n" "http_proxy|HTTP_PROXY" "e.g. \"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\""
    printf "\t%s\t%b\n" "https_proxy|HTTPS_PROXY" "e.g. \"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\""
    echo ""
    echo "EXIT STATUS"
    printf "\t%b\n" "The ${BLUE}${PGM}${COLOR_END} utility exits 0 on success, and >0 if an error occurs."
    echo ""
    echo "VERSION"
    printf "\t%s\n" "${VERSION}"
    echo ""
}

check_result() {
    if [ "$1" -eq 0 ]; then
        printf "%b\n" "${GREEN}[OK]${COLOR_END}"
    else
        printf "%b\n" "${RED}[ERROR]${COLOR_END}"
        echo ""
        if [ "${DUMP_LOG_ON_ERROR}" = "0" ]; then
            echo "Check build log in ${LOG_DIR}/${LOG_FILE}"
        else
            echo "last ${LOG_LINES} lines from ${LOG_DIR}/${LOG_FILE}:"
            echo "-----------------------------------------------"
            if [ -f "${LOG_DIR}/${LOG_FILE}" ]; then
                tail -n "${LOG_LINES}" "${LOG_DIR}/${LOG_FILE}"
            else
                echo "Log file ${LOG_DIR}/${LOG_FILE} not found."
            fi
            echo ""
            echo "-------------"
        fi
        printf "%b\n" "${RED}build aborted${COLOR_END}"
        echo ""
        exit "$1"
    fi
}

program_exists() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    fi
    printf "%s is not available, please install and try again!\n" "$1" >> "${LOG_DIR}/dependencies.log" 2>&1
    return 1
}

download_archive() {
    archive_url="$1"
    archive_path="$2"
    log_file="$3"

    if [ ! -f "${archive_path}" ]; then
        
        if ! wget --no-verbose "${archive_url}" -O "${archive_path}" > "${LOG_DIR}/${log_file}" 2>&1; then
            return 1
        fi
    fi
    return 0
}

ensure_directories() {
    mkdir -p -- "${TMUX_STATIC_HOME}/src" "${TMUX_STATIC_HOME}/lib" "${TMUX_STATIC_HOME}/bin" "${TMUX_STATIC_HOME}/include" "${LOG_DIR}"
}

cleanup() {
    printf "%b\n" "${BLUE}Cleaning up...${COLOR_END}"
    rm -rf -- "${TMUX_STATIC_HOME:?}/include"/*
    rm -rf -- "${TMUX_STATIC_HOME:?}/lib"/*
    rm -rf -- "${TMUX_STATIC_HOME:?}/bin"/*
    rm -rf -- "${LOG_DIR}"/*
    rm -rf -- "${TMUX_STATIC_HOME}/src/musl-${MUSL_VERSION}"
    rm -rf -- "${TMUX_STATIC_HOME}/src/libevent-${LIBEVENT_VERSION}-stable"
    rm -rf -- "${TMUX_STATIC_HOME}/src/ncurses-${NCURSES_VERSION}"
    rm -rf -- "${TMUX_STATIC_HOME}/src/tmux-${TMUX_VERSION}"
    rm -rf -- "${TMUX_STATIC_HOME}/src/upx-${UPX_VERSION}-${ARCH}_${OS}"
}

build_musl() {
    LOG_FILE="musl-${MUSL_VERSION}.log"
    cd "${TMUX_STATIC_HOME}/src" || exit 1
    
    printf "Downloading..."
    download_archive "${MUSL_URL}/${MUSL_ARCHIVE}" "${MUSL_ARCHIVE}" "${LOG_FILE}"
    check_result $?

    printf "Extracting...."
    tar xf "${MUSL_ARCHIVE}" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    cd "musl-${MUSL_VERSION}" || exit 1
    printf "Configuring..."
    ./configure \
        --enable-gcc-wrapper \
        --disable-shared \
        --prefix="${TMUX_STATIC_HOME}" \
        --bindir="${TMUX_STATIC_HOME}/bin" \
        --includedir="${TMUX_STATIC_HOME}/include" \
        --libdir="${TMUX_STATIC_HOME}/lib" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    printf "Compiling....."
    make -j"${JOB_COUNT}" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    printf "Installing...."
    make install >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    export CC="${TMUX_STATIC_HOME}/bin/musl-gcc -static"
}

build_libevent() {
    LOG_FILE="libevent-${LIBEVENT_VERSION}-stable.log"
    cd "${TMUX_STATIC_HOME}/src" || exit 1

    printf "Downloading..."
    download_archive "${LIBEVENT_URL}/${LIBEVENT_ARCHIVE}" "${LIBEVENT_ARCHIVE}" "${LOG_FILE}"
    check_result $?

    printf "Extracting...."
    tar xf "${LIBEVENT_ARCHIVE}" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    cd "libevent-${LIBEVENT_VERSION}-stable" || exit 1
    printf "Configuring..."
    ./configure \
        --prefix="${TMUX_STATIC_HOME}" \
        --includedir="${TMUX_STATIC_HOME}/include" \
        --libdir="${TMUX_STATIC_HOME}/lib" \
        --disable-shared \
        --disable-openssl \
        --disable-libevent-regress \
        --disable-samples >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    printf "Compiling....."
    make -j"${JOB_COUNT}" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    printf "Installing...."
    make install >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?
}

build_ncurses() {
    LOG_FILE="ncurses-${NCURSES_VERSION}.log"
    cd "${TMUX_STATIC_HOME}/src" || exit 1

    printf "Downloading..."
    download_archive "${NCURSES_URL}/${NCURSES_ARCHIVE}" "${NCURSES_ARCHIVE}" "${LOG_FILE}"
    check_result $?

    printf "Extracting...."
    tar xf "${NCURSES_ARCHIVE}" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    cd "ncurses-${NCURSES_VERSION}" || exit 1
    printf "Configuring..."
    ./configure \
        --prefix="${TMUX_STATIC_HOME}" \
        --includedir="${TMUX_STATIC_HOME}/include" \
        --libdir="${TMUX_STATIC_HOME}/lib" \
        --enable-pc-files \
        --with-pkg-config="${TMUX_STATIC_HOME}/lib/pkgconfig" \
        --with-pkg-config-libdir="${TMUX_STATIC_HOME}/lib/pkgconfig" \
        --without-ada \
        --without-cxx \
        --without-cxx-binding \
        --without-tests \
        --without-manpages \
        --without-debug \
        --disable-lib-suffixes \
        --with-ticlib \
        --with-termlib \
        --with-default-terminfo-dir=/usr/share/terminfo \
        --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo \
        --disable-shared >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    printf "Compiling....."
    make -j"${JOB_COUNT}" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    printf "Installing...."
    make install.libs >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?
}

build_tmux() {
    LOG_FILE="tmux-${TMUX_VERSION}.log"
    cd "${TMUX_STATIC_HOME}/src" || exit 1

    printf "Downloading..."
    download_archive "${TMUX_URL}/${TMUX_ARCHIVE}" "${TMUX_ARCHIVE}" "${LOG_FILE}"
    check_result $?
    printf "Extracting...."
    tar xf "${TMUX_ARCHIVE}" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    cd "tmux-${TMUX_VERSION}" || exit 1
    printf "Configuring..."
    ./configure --prefix="${TMUX_STATIC_HOME}" \
        --enable-static \
        --includedir="${TMUX_STATIC_HOME}/include" \
        --libdir="${TMUX_STATIC_HOME}/lib" \
        CFLAGS="-I${TMUX_STATIC_HOME}/include" \
        LDFLAGS="-L${TMUX_STATIC_HOME}/lib" \
        CPPFLAGS="-I${TMUX_STATIC_HOME}/include" \
        LIBEVENT_LIBS="-L${TMUX_STATIC_HOME}/lib -levent" \
        LIBNCURSES_CFLAGS="-I${TMUX_STATIC_HOME}/include/ncurses" \
        LIBNCURSES_LIBS="-L${TMUX_STATIC_HOME}/lib -lncurses" \
        LIBTINFO_CFLAGS="-I${TMUX_STATIC_HOME}/include/ncurses" \
        LIBTINFO_LIBS="-L${TMUX_STATIC_HOME}/lib -ltinfo" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    printf "Compiling....."
    make -j"${JOB_COUNT}" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    printf "Installing...."
    make install >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?
}

compress_with_upx() {
    LOG_FILE="upx-${UPX_VERSION}.log"
    echo ""
    echo "Compressing binary with UPX ${UPX_VERSION}"
    echo "--------------------------------"

    cd "${TMUX_STATIC_HOME}/src" || exit 1
    download_archive "${UPX_URL}/${UPX_ARCHIVE}" "${UPX_ARCHIVE}" "${LOG_FILE}"
    tar xf "${UPX_ARCHIVE}" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?

    cd "upx-${UPX_VERSION}-${ARCH}_${OS}" || exit 1
    mv upx "${TMUX_STATIC_HOME}/bin/"

    cp "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped" "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.upx"
    printf "Compressing..."
    "${TMUX_STATIC_HOME}/bin/upx" -q --best --ultra-brute "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.upx" >> "${LOG_DIR}/${LOG_FILE}" 2>&1
    check_result $?
}

get_args() {
    while getopts "hcd" option; do
        case "${option}" in
            h)
                usage
                exit 0
                ;;
            c)
                USE_UPX=1
                ;;
            d)
                DUMP_LOG_ON_ERROR=1
                ;;
            *)
                echo ""
                usage_options
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))
}

get_args "$@"

ensure_directories
cleanup

printf "%b\n" "${BLUE}current settings${COLOR_END}"
echo "-------------------"
echo "USE_UPX:           ${USE_UPX}"
echo "DUMP_LOG_ON_ERROR: ${DUMP_LOG_ON_ERROR}"
echo "LOG_LINES:         ${LOG_LINES}"

echo ""
echo "Dependencies"
echo "-------------------"
for prog in gcc wget tar make strip gzip; do
    printf "%-14.14s" "${prog}............."
    program_exists "${prog}"
    check_result $?
done

# yacc is optional if bison exists
if command -v yacc >/dev/null 2>&1; then
    :
elif command -v bison >/dev/null 2>&1; then
    export YACC="bison -y"
else
    printf "yacc or bison is not available, please install one and try again!\n" >> "${LOG_DIR}/dependencies.log" 2>&1
    check_result 1
fi

printf "\n%b\n" "${BLUE}********************************************${COLOR_END}"
printf "%b\n"   "${BLUE}** Starting to build a static TMUX binary **${COLOR_END}"
printf "%b\n"   "${BLUE}********************************************${COLOR_END}"

TIME_START=$(date +%s)

printf "\n%s\n" "${MUSL_ARCHIVE}"
echo "------------------"
build_musl

printf "\n%s\n" "${LIBEVENT_ARCHIVE}"
echo "------------------"
build_libevent

printf "\n%s\n" "${NCURSES_ARCHIVE}"
echo "------------------"
build_ncurses

printf "\n%s\n" "${TMUX_ARCHIVE}"
echo "------------------"
build_tmux

cd "${TMUX_STATIC_HOME}" || exit 1
cp "${TMUX_STATIC_HOME}/bin/tmux" "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}"
cp "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}" "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped"
printf "Stripping....."
strip --strip-all "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped"
check_result $?

if [ "${USE_UPX}" = "1" ]; then
    compress_with_upx
fi

gzip -k -f "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}"
gzip -k -f "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped"
if [ "${USE_UPX}" = "1" ]; then
    gzip -k -f "${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.upx"
fi

echo ""
echo "Resulting files:"
echo "----------------"
echo "Standard tmux binary:   ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.gz"
echo "Stripped tmux binary:   ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped.gz"
if [ "${USE_UPX}" = "1" ]; then
    echo "Compressed tmux binary: ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.upx.gz"
fi

echo ""
echo "----------------------------------------"
TIME_END=$(date +%s)
TIME_DIFF=$((TIME_END - TIME_START))
echo "Duration: $((TIME_DIFF / 3600))h $(((TIME_DIFF / 60) % 60))m $((TIME_DIFF % 60))s"
echo ""
