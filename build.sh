#!/bin/sh
# Exit on error #
#set -e

export CC=gcc-6
export REALCC=${CC}
export CPPFLAGS="-P"

# set this variable to 'TRUE' to compress the resulting
# executable with UPX
export USE_UPX="TRUE"

# ANSI Farb Codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
COLOR_END="\033[0m"

#TMUX_STATIC_HOME="${HOME}/tmux-static"
TMUX_STATIC_HOME="/tmp/tmux-static"

TMUX_VERSION=2.8
TMUX_URL="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}"

MUSL_VERSION=1.1.21
MUSL_URL="https://www.musl-libc.org/releases"

NCURSES_VERSION=6.1
NCURSES_URL="http://ftp.gnu.org/gnu/ncurses"

LIBEVENT_VERSION=2.1.8
LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable"

UPX_VERSION=3.95
UPX_URL="https://github.com/upx/upx/releases/download/v${UPX_VERSION}"

START_TIME=$(date '+%d.%m.%Y %H:%M:%S')

checkResult ()
{
if [ $1 -eq 0 ]; then
    echo -e "${GREEN}[OK]${COLOR_END}"
else
    echo -e "${RED}[ERROR]${COLOR_END}"
    echo "Check Buildlog in ${TMUX_STATIC_HOME}/log/"
    echo ""
    exit 1
fi
}

clear

# create directories
[ ! -d ${TMUX_STATIC_HOME} ]         && mkdir ${TMUX_STATIC_HOME}
[ ! -d ${TMUX_STATIC_HOME}/src ]     && mkdir ${TMUX_STATIC_HOME}/src
[ ! -d ${TMUX_STATIC_HOME}/lib ]     && mkdir ${TMUX_STATIC_HOME}/lib
[ ! -d ${TMUX_STATIC_HOME}/bin ]     && mkdir ${TMUX_STATIC_HOME}/bin
[ ! -d ${TMUX_STATIC_HOME}/log ]     && mkdir ${TMUX_STATIC_HOME}/log
[ ! -d ${TMUX_STATIC_HOME}/include ] && mkdir ${TMUX_STATIC_HOME}/include

# Clean up #
rm -rf ${TMUX_STATIC_HOME}/include/*
rm -rf ${TMUX_STATIC_HOME}/lib/*
rm -rf ${TMUX_STATIC_HOME}/bin/*
rm -rf ${TMUX_STATIC_HOME}/log/*

rm -rf ${TMUX_STATIC_HOME}/src/upx-${UPX_VERSION}-amd64_linux
rm -rf ${TMUX_STATIC_HOME}/src/musl-${MUSL_VERSION}
rm -rf ${TMUX_STATIC_HOME}/src/libevent-${LIBEVENT_VERSION}-stable
rm -rf ${TMUX_STATIC_HOME}/src/ncurses-${NCURSES_VERSION}
rm -rf ${TMUX_STATIC_HOME}/src/tmux-${TMUX_VERSION}

echo -e "${BLUE}*************************************${COLOR_END}"
echo -e "${BLUE}** Starting to build a static TMUX **${COLOR_END}"
echo -e "${BLUE}*************************************${COLOR_END}"

echo ""
echo "HINT:"
echo "In case you are behind a proxy, you can define the http_proxy"
echo "variables to download the necessary files like this:"
echo -e "${YELLOW}export http_proxy=\"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\"${COLOR_END}"
echo -e "${YELLOW}export https_proxy=\"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\"${COLOR_END}"

echo ""
echo "musl ${MUSL_VERSION}"
echo "----------------"

cd ${TMUX_STATIC_HOME}/src
if [ ! -f musl-${MUSL_VERSION}.tar.gz ]; then
    echo -n "Downloading..."
    wget -q ${MUSL_URL}/musl-${MUSL_VERSION}.tar.gz
    checkResult $?
fi

echo -n "Extracting...."
tar xzf musl-${MUSL_VERSION}.tar.gz
checkResult $?

cd musl-${MUSL_VERSION}

echo -n "Configuring..."
./configure --enable-gcc-wrapper --disable-shared --prefix=${TMUX_STATIC_HOME} --bindir=${TMUX_STATIC_HOME}/bin --includedir=${TMUX_STATIC_HOME}/include --libdir=${TMUX_STATIC_HOME}/lib > ${TMUX_STATIC_HOME}/log/musl-${MUSL_VERSION}.log 2>&1
checkResult $?

echo -n "Compiling....."
make >> ${TMUX_STATIC_HOME}/log/musl-${MUSL_VERSION}.log 2>&1
checkResult $?

echo -n "Installing...."
make install >> ${TMUX_STATIC_HOME}/log/musl-${MUSL_VERSION}.log 2>&1
checkResult $?

export CC="${TMUX_STATIC_HOME}/bin/musl-gcc -static"

echo ""
echo "libevent ${LIBEVENT_VERSION}-stable"
echo "----------------"

cd ${TMUX_STATIC_HOME}/src
if [ ! -f libevent-${LIBEVENT_VERSION}-stable.tar.gz ]; then
    echo -n "Downloading..."
    wget -q ${LIBEVENT_URL}/libevent-${LIBEVENT_VERSION}-stable.tar.gz
    checkResult $?
fi

echo -n "Extracting...."
tar xzf libevent-${LIBEVENT_VERSION}-stable.tar.gz
checkResult $?

cd libevent-${LIBEVENT_VERSION}-stable

echo -n "Configuring..."
./configure --prefix=${TMUX_STATIC_HOME} --includedir=${TMUX_STATIC_HOME}/include --libdir=${TMUX_STATIC_HOME}/lib --disable-shared --disable-samples > ${TMUX_STATIC_HOME}/log/libevent-${LIBEVENT_VERSION}-stable.log 2>&1
checkResult $?

echo -n "Compiling....."
make >> ${TMUX_STATIC_HOME}/log/libevent-${LIBEVENT_VERSION}-stable.log 2>&1
checkResult $?

echo -n "Installing...."
make install >> ${TMUX_STATIC_HOME}/log/libevent-${LIBEVENT_VERSION}-stable.log 2>&1
checkResult $?

echo ""
echo "ncurses ${NCURSES_VERSION}"
echo "----------------"

cd ${TMUX_STATIC_HOME}/src
if [ ! -f ncurses-${NCURSES_VERSION}.tar.gz ]; then
    echo -n "Downloading..."
    wget -q ${NCURSES_URL}/ncurses-${NCURSES_VERSION}.tar.gz
    checkResult $?
fi

echo -n "Extracting...."
tar xzf ncurses-${NCURSES_VERSION}.tar.gz
checkResult $?

cd ncurses-${NCURSES_VERSION}

echo -n "Configuring..."
./configure --prefix=${TMUX_STATIC_HOME} --includedir=${TMUX_STATIC_HOME}/include --libdir=${TMUX_STATIC_HOME}/lib --enable-pc-files --with-pkg-config=${TMUX_STATIC_HOME}/lib/pkgconfig --with-pkg-config-libdir=${TMUX_STATIC_HOME}/lib/pkgconfig --without-ada --without-tests --without-manpages --with-ticlib --with-termlib --with-default-terminfo-dir=/usr/share/terminfo --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo > ${TMUX_STATIC_HOME}/log/ncurses-${NCURSES_VERSION}.log 2>&1
checkResult $?

echo -n "Compiling....."
make >> ${TMUX_STATIC_HOME}/log/ncurses-${NCURSES_VERSION}.log 2>&1
checkResult $?

echo -n "Installing...."
make install >> ${TMUX_STATIC_HOME}/log/ncurses-${NCURSES_VERSION}.log 2>&1
checkResult $?

echo ""
echo "tmux ${TMUX_VERSION}"
echo "----------------"

cd ${TMUX_STATIC_HOME}/src
if [ ! -f tmux-${TMUX_VERSION}.tar.gz ]; then
    echo -n "Downloading..."
    wget -q ${TMUX_URL}/tmux-${TMUX_VERSION}.tar.gz
    checkResult $?
fi

echo -n "Extracting...."
tar xzf tmux-${TMUX_VERSION}.tar.gz
checkResult $?

cd tmux-${TMUX_VERSION}

echo -n "Configuring..."
./configure --prefix=${TMUX_STATIC_HOME} --enable-static --includedir="${TMUX_STATIC_HOME}/include" --libdir="${TMUX_STATIC_HOME}/lib" CFLAGS="-I${TMUX_STATIC_HOME}/include" LDFLAGS="-L${TMUX_STATIC_HOME}/lib" CPPFLAGS="-I${TMUX_STATIC_HOME}/include" LIBEVENT_LIBS="-L${TMUX_STATIC_HOME}/lib -levent" LIBNCURSES_CFLAGS="-I${TMUX_STATIC_HOME}/include/ncurses" LIBNCURSES_LIBS="-L${TMUX_STATIC_HOME}/lib -lncurses" LIBTINFO_CFLAGS="-I${TMUX_STATIC_HOME}/include/ncurses" LIBTINFO_LIBS="-L${TMUX_STATIC_HOME}/lib -ltinfo" > ${TMUX_STATIC_HOME}/log/tmux-${TMUX_VERSION}.log 2>&1
checkResult $?

echo -n "Compiling....."
make >> ${TMUX_STATIC_HOME}/log/tmux-${TMUX_VERSION}.log 2>&1
checkResult $?

echo -n "Installing...."
make install >> ${TMUX_STATIC_HOME}/log/tmux-${TMUX_VERSION}.log 2>&1
checkResult $?

cd ${TMUX_STATIC_HOME}

# strip text from binary
cp ${TMUX_STATIC_HOME}/bin/tmux ${TMUX_STATIC_HOME}/bin/tmux.stripped
echo -n "Stripping....."
strip ${TMUX_STATIC_HOME}/bin/tmux.stripped
checkResult $?

# compress with upx, when choosen
if [ ! -z ${USE_UPX} ] && [ ${USE_UPX} == "TRUE" ]; then
    echo ""
    echo "Compressing binary with UPX ${UPX_VERSION}"
    echo "--------------------------------"
    cd ${TMUX_STATIC_HOME}/src
    if [ ! -f upx-${UPX_VERSION}-amd64_linux.tar.xz ]; then
        echo -n "Downloading..."
        wget -q ${UPX_URL}/upx-${UPX_VERSION}-amd64_linux.tar.xz
        checkResult $?
    fi
    tar xJf upx-${UPX_VERSION}-amd64_linux.tar.xz
    cd upx-${UPX_VERSION}-amd64_linux
    mv upx ${TMUX_STATIC_HOME}/bin/

    # compress binary with upx
    cp ${TMUX_STATIC_HOME}/bin/tmux.stripped ${TMUX_STATIC_HOME}/bin/tmux.upx
    echo -n "Compressing..."
    ${TMUX_STATIC_HOME}/bin/upx -q --best --ultra-brute ${TMUX_STATIC_HOME}/bin/tmux.upx > /dev/null 2>&1
    checkResult $?
fi

echo ""
echo "Standard tmux binary:   ${TMUX_STATIC_HOME}/bin/tmux"
echo "Stripped tmux binary:   ${TMUX_STATIC_HOME}/bin/tmux.stripped"
if [ ! -z ${USE_UPX} ] && [ ${USE_UPX} == "TRUE" ]; then
    echo "Compressed tmux binary: ${TMUX_STATIC_HOME}/bin/tmux.upx"
fi

echo ""
echo "----------------------------------------"
echo "Start: ${START_TIME}"
echo "End:   $(date '+%d.%m.%Y %H:%M:%S')"
echo ""
