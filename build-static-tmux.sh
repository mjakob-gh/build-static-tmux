#!/bin/sh

export CC=cc
export REALCC=${CC}
export CPPFLAGS="-P"

# ANSI Color Codes
RED="\033[0;31m"
GREEN="\033[0;32m"
#YELLOW="\033[0;33m"
BLUE="\033[0;34m"
COLOR_END="\033[0m"

# Program basename
PGM="${0##*/}" # Program basename

# Scriptversion
VERSION=3.5d

# How many lines of the error log should be displayed
LOG_LINES=50

# os and pocessor architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# sigh, in linux some use "x86_64", "aarch64"
# and others "amd64" or "arm64" the upx developers 
case "$(uname -m)" in
    "aarch64")
        ARCH="arm64"
        ;;
    "x86_64")
        ARCH="amd64"
        ;;
    *)
        ARCH=$(uname -m)
        ;;
esac

TMUX_BIN="tmux.${OS}-${ARCH}"

######################################
###### BEGIN VERSION DEFINITION ######
######################################
TMUX_VERSION=3.5a
MUSL_VERSION=1.2.5
NCURSES_VERSION=6.5
LIBEVENT_VERSION=2.1.12
UPX_VERSION=5.0.1
######################################
####### END VERSION DEFINITION #######
######################################

#TMUX_STATIC_HOME="${HOME}/tmux-static"
TMUX_STATIC_HOME="${TMUX_STATIC_HOME:-/tmp/tmux-static}"

LOG_DIR="${TMUX_STATIC_HOME}/log"

TMUX_ARCHIVE="tmux-${TMUX_VERSION}.tar.gz"
TMUX_URL="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}"

MUSL_ARCHIVE="musl-${MUSL_VERSION}.tar.gz"
MUSL_URL="https://musl.libc.org/releases/"

NCURSES_ARCHIVE="ncurses-${NCURSES_VERSION}.tar.gz"
NCURSES_URL="https://invisible-island.net/archives/ncurses/"

LIBEVENT_ARCHIVE="libevent-${LIBEVENT_VERSION}-stable.tar.gz"
LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable"

UPX_ARCHIVE="upx-${UPX_VERSION}-${ARCH}_${OS}.tar.xz"
UPX_URL="https://github.com/upx/upx/releases/download/v${UPX_VERSION}"

#
# decipher the programm arguments
#
get_args()
{
    while getopts "hcd" option
    do
        case $option in
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
            '')
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

#
# print valid options
#
usage_options()
{
    printf "\t%s\n" "The following options are available:"
    echo ""
    printf "\t%b\t%s\n" "${BLUE}-c${COLOR_END}" "compress the resulting binary with UPX."
    echo ""
    printf "\t%b\t%s\n" "${BLUE}-d${COLOR_END}" "dump the log of the current buildstep to stdout if an error occurs."
    echo ""
    printf "\t%b\t%s\n" "${BLUE}-h${COLOR_END}" "print this help message."
    echo ""
}

#
# print the usage message
#
usage()
{
    exec >&2
    echo   ""
    echo "NAME"
    printf "\t%b - %s\n" "${BLUE}${PGM}${COLOR_END}" "build a static TMUX release"
    echo   ""
    echo   "SYNOPSIS"
    printf "\t%b" "${BLUE}${PGM} [-h | -c -d]${COLOR_END}\n"
    echo ""
    echo   "DESCRIPTION"
    usage_options
    echo "ENVIRONMENT"
    printf "\t%b\n" "The following environment variables affect the execution of ${BLUE}${PGM}${COLOR_END}"
    echo ""
    printf "\t%s\t\t\t%b\n" "USE_UPX" "set to \"1\" to compress the resulting binary with UPX (see argument ${BLUE}-c${COLOR_END} above)."
    echo ""
    printf "\t%s\t%b\n" "DUMP_LOG_ON_ERROR" "set to \"1\" to dump the log of the current buildstep to stdout if an error occurs (see argument ${BLUE}-d${COLOR_END} above)."
    echo ""
    printf "\t%s\n" "In case you are behind a proxy, export these environment variables to download the necessary files:"
    printf "\t%s\t%b\n" "http_proxy|HTTP_PROXY" "e.g. \"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\""
    printf "\t%s\t%b\n" "https_proxy|HTTPS_PROXY" "e.g. \"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\""
    echo ""
    echo "EXIT STATUS"
    printf "\t%b\n" "The ${BLUE}${PGM}${COLOR_END} utility exits 0 on success, and >0 if an error occurs."
    echo ""
    echo "VERSION"
    printf "\t%s\n" "${VERSION}"
    echo ""
}

#
# check the returncode of the last programm
# and print a nice status message
#
checkResult ()
{
    if [ "$1" -eq 0 ]; then
        printf "%b\n" "${GREEN}[OK]${COLOR_END}"
    else
        printf "%b\n" "${RED}[ERROR]${COLOR_END}"
        echo ""
        if [ ${DUMP_LOG_ON_ERROR} = 0 ]; then
            echo "Check Buildlog in ${LOG_DIR}/${LOG_FILE}"
        else
            echo "last ${LOG_LINES} from ${LOG_DIR}/${LOG_FILE}:"
            echo "-----------------------------------------------"
            echo "..."
            if [ -f "${LOG_DIR}/${LOG_FILE}" ]; then
                tail -n ${LOG_LINES} "${LOG_DIR}/${LOG_FILE}"
            else
                echo "Oops, logfile ${LOG_DIR}/${LOG_FILE} not found, something gone wrong!"
            fi
            echo ""
            echo "-------------"
            printf "%b\n" "${RED}build aborted${COLOR_END}"
            echo ""
        fi
        exit $1
    fi
}

#
# Check if the needed tools are installed
# gcc, yacc
#
programExists ()
{
    LOG_FILE="dependencies.log"
    if command -v "$1" > /dev/null 2>&1; then
        return 0
    else
        echo "$1 is not available, please install and try again!" >> ${LOG_DIR}/${LOG_FILE} 2>&1
        return 1
    fi
}

# export this variables with value 1 in the shell,
# or use the -c and/or -d argument
# compress the resulting executable with UPX
USE_UPX=${USE_UPX:-0}
# print the last x lines of the log to stdout
DUMP_LOG_ON_ERROR=${DUMP_LOG_ON_ERROR:-0}

get_args "$@"

clear

# create directories initially
[ ! -d ${TMUX_STATIC_HOME} ]         && mkdir ${TMUX_STATIC_HOME}
[ ! -d ${TMUX_STATIC_HOME}/src ]     && mkdir ${TMUX_STATIC_HOME}/src
[ ! -d ${TMUX_STATIC_HOME}/lib ]     && mkdir ${TMUX_STATIC_HOME}/lib
[ ! -d ${TMUX_STATIC_HOME}/bin ]     && mkdir ${TMUX_STATIC_HOME}/bin
[ ! -d ${TMUX_STATIC_HOME}/include ] && mkdir ${TMUX_STATIC_HOME}/include
[ ! -d ${LOG_DIR} ]                  && mkdir ${LOG_DIR}

# Clean up #
printf "%b\n" "${BLUE}Cleaning up...${COLOR_END}"
rm -rf ${TMUX_STATIC_HOME:?}/include/*
rm -rf ${TMUX_STATIC_HOME:?}/lib/*
rm -rf ${TMUX_STATIC_HOME:?}/bin/*
rm -rf ${LOG_DIR:?}/*

rm -rf ${TMUX_STATIC_HOME:?}/src/upx-${UPX_VERSION}-amd64_linux
rm -rf ${TMUX_STATIC_HOME:?}/src/musl-${MUSL_VERSION}
rm -rf ${TMUX_STATIC_HOME:?}/src/libevent-${LIBEVENT_VERSION}-stable
rm -rf ${TMUX_STATIC_HOME:?}/src/ncurses-${NCURSES_VERSION}
rm -rf ${TMUX_STATIC_HOME:?}/src/tmux-${TMUX_VERSION}

echo ""
echo "current settings"
echo "----------------"
echo "USE_UPX:           ${USE_UPX}"
echo "DUMP_LOG_ON_ERROR: ${DUMP_LOG_ON_ERROR}"
echo "LOG_LINES:         ${LOG_LINES}"

echo ""
echo "Dependencies"
echo "------------"
printf "gcc..........."
programExists "gcc"
checkResult $?
printf "yacc.........."
programExists "yacc"
checkResult $?

echo ""
printf "%b\n" "${BLUE}*********************************************${COLOR_END}"
printf "%b\n" "${BLUE}** Starting to build a static TMUX release **${COLOR_END}"
printf "%b\n" "${BLUE}*********************************************${COLOR_END}"

TIME_START=$(date +%s)

###############################################################
echo ""
echo "musl ${MUSL_VERSION}"
echo "------------------"

LOG_FILE="musl-${MUSL_VERSION}.log"

cd ${TMUX_STATIC_HOME}/src || exit 1
if [ ! -f ${MUSL_ARCHIVE} ]; then
    printf "Downloading..."
    wget --no-verbose ${MUSL_URL}/${MUSL_ARCHIVE} > ${LOG_DIR}/${LOG_FILE} 2>&1
    checkResult $?
fi

printf "Extracting...."
tar xzf ${MUSL_ARCHIVE}
checkResult $?

cd musl-${MUSL_VERSION} || exit 1

printf "Configuring..."
./configure \
    --enable-gcc-wrapper \
    --disable-shared \
    --prefix=${TMUX_STATIC_HOME} \
    --bindir=${TMUX_STATIC_HOME}/bin \
    --includedir=${TMUX_STATIC_HOME}/include \
    --libdir=${TMUX_STATIC_HOME}/lib >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

printf "Compiling....."
make >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

printf "Installing...."
make install >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

export CC="${TMUX_STATIC_HOME}/bin/musl-gcc -static"

###############################################################
echo ""
echo "libevent ${LIBEVENT_VERSION}-stable"
echo "------------------"

LOG_FILE="libevent-${LIBEVENT_VERSION}-stable.log"

cd ${TMUX_STATIC_HOME}/src || exit 1
if [ ! -f ${LIBEVENT_ARCHIVE} ]; then
    printf "Downloading..."
    wget --no-verbose ${LIBEVENT_URL}/${LIBEVENT_ARCHIVE} > ${LOG_DIR}/${LOG_FILE} 2>&1
    checkResult $?
fi

printf "Extracting...."
tar xzf ${LIBEVENT_ARCHIVE}
checkResult $?

cd libevent-${LIBEVENT_VERSION}-stable || exit 1

printf "Configuring..."
./configure \
    --prefix=${TMUX_STATIC_HOME}             \
    --includedir=${TMUX_STATIC_HOME}/include \
    --libdir=${TMUX_STATIC_HOME}/lib         \
    --disable-shared                         \
    --disable-openssl                        \
    --disable-libevent-regress               \
    --disable-samples                        \
    >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

printf "Compiling....."
make >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

printf "Installing...."
make install >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

###############################################################
echo ""
echo "ncurses ${NCURSES_VERSION}"
echo "------------------"

LOG_FILE="ncurses-${NCURSES_VERSION}.log"

cd ${TMUX_STATIC_HOME}/src || exit 1
if [ ! -f ${NCURSES_ARCHIVE} ]; then
    printf "Downloading..."
    wget --no-verbose ${NCURSES_URL}/${NCURSES_ARCHIVE} > ${LOG_DIR}/${LOG_FILE} 2>&1
    checkResult $?
fi

printf "Extracting...."
tar xzf ${NCURSES_ARCHIVE}
checkResult $?

cd ncurses-${NCURSES_VERSION} || exit 1

printf "Configuring..."
./configure \
    --prefix=${TMUX_STATIC_HOME} \
    --includedir=${TMUX_STATIC_HOME}/include \
    --libdir=${TMUX_STATIC_HOME}/lib \
    --enable-pc-files \
    --with-pkg-config=${TMUX_STATIC_HOME}/lib/pkgconfig \
    --with-pkg-config-libdir=${TMUX_STATIC_HOME}/lib/pkgconfig \
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
    >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

printf "Compiling....."
make >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

make >> /dev/null

printf "Installing...."
make install.libs >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

###############################################################
echo ""
echo "tmux ${TMUX_VERSION}"
echo "------------------"

LOG_FILE="tmux-${TMUX_VERSION}.log"

cd ${TMUX_STATIC_HOME}/src || exit 1
if [ ! -f ${TMUX_ARCHIVE} ]; then
    printf "Downloading..."
    wget --no-verbose ${TMUX_URL}/${TMUX_ARCHIVE} > ${LOG_DIR}/${LOG_FILE} 2>&1
    checkResult $?
fi

printf "Extracting...."
tar xzf ${TMUX_ARCHIVE}
checkResult $?

cd tmux-${TMUX_VERSION} || exit 1

printf "Configuring..."
./configure --prefix=${TMUX_STATIC_HOME} \
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
    LIBTINFO_LIBS="-L${TMUX_STATIC_HOME}/lib -ltinfo" >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

# patch file.c
#sed -i 's|#include <sys/queue.h>||g' file.c

printf "Compiling....."
make >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

printf "Installing...."
make install >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

###############################################################

cd ${TMUX_STATIC_HOME} || exit 1

# strip text from binary
cp ${TMUX_STATIC_HOME}/bin/tmux ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}
cp ${TMUX_STATIC_HOME}/bin/${TMUX_BIN} ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped
printf "Stripping....."
strip ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped
checkResult $?

# compress with upx, when choosen
if [ -n "${USE_UPX}" ] && [ ${USE_UPX} = 1 ]; then
    LOG_FILE="upx-${UPX_VERSION}.log"
    echo ""
    echo "Compressing binary with UPX ${UPX_VERSION}"
    echo "--------------------------------"
    cd ${TMUX_STATIC_HOME}/src || exit 1
    if [ ! -f ${UPX_ARCHIVE} ]; then
        printf "Downloading..."
        wget --no-verbose ${UPX_URL}/${UPX_ARCHIVE} >> ${LOG_DIR}/${LOG_FILE} 2>&1
        checkResult $?
    fi
    tar xJf ${UPX_ARCHIVE}
    cd upx-${UPX_VERSION}-${ARCH}_${OS} || exit 1
    mv upx ${TMUX_STATIC_HOME}/bin/

    # compress binary with upx
    cp ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.upx
    printf "Compressing..."
    ${TMUX_STATIC_HOME}/bin/upx -q --best --ultra-brute ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.upx >> ${LOG_DIR}/${LOG_FILE} 2>&1
    checkResult $?
fi

echo ""
echo "Resulting files:"
echo "----------------"
echo "Standard tmux binary:   ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.gz"
echo "Stripped tmux binary:   ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped.gz"

gzip ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}
gzip ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.stripped

if [ -n "${USE_UPX}" ] && [ ${USE_UPX} = 1 ]; then
    echo "Compressed tmux binary: ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.upx.gz"
	gzip ${TMUX_STATIC_HOME}/bin/${TMUX_BIN}.upx
fi

echo ""
echo "----------------------------------------"
TIME_END=$(date +%s)
TIME_DIFF=$((TIME_END - TIME_START))
echo "Duration: $((TIME_DIFF / 3600))h $(((TIME_DIFF / 60) % 60))m $((TIME_DIFF % 60))s"
echo ""
