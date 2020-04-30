#!/bin/sh

export CC=gcc
export REALCC=${CC}
export CPPFLAGS="-P"

# set this variable to 'TRUE' to compress the resulting
# executable with UPX
export USE_UPX="TRUE"

# ANSI Color Codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
COLOR_END="\033[0m"


######################################
###### BEGIN VERSION DEFINITION ######
######################################
TMUX_VERSION=3.1
MUSL_VERSION=1.2.0
NCURSES_VERSION=6.1
LIBEVENT_VERSION=2.1.11
UPX_VERSION=3.95
######################################
####### END VERSION DEFINITION #######
######################################

#TMUX_STATIC_HOME="${HOME}/tmux-static"
TMUX_STATIC_HOME="/tmp/tmux-static"

LOG_DIR="${TMUX_STATIC_HOME}/log"

TMUX_ARCHIVE="tmux-${TMUX_VERSION}.tar.gz"
TMUX_URL="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}"

MUSL_ARCHIVE="musl-${MUSL_VERSION}.tar.gz"
MUSL_URL="https://www.musl-libc.org/releases"

NCURSES_ARCHIVE="ncurses-${NCURSES_VERSION}.tar.gz"
NCURSES_URL="http://ftp.gnu.org/gnu/ncurses"

LIBEVENT_ARCHIVE="libevent-${LIBEVENT_VERSION}-stable.tar.gz"
LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable"

UPX_ARCHIVE="upx-${UPX_VERSION}-amd64_linux.tar.xz"
UPX_URL="https://github.com/upx/upx/releases/download/v${UPX_VERSION}"

START_TIME=$(date '+%d.%m.%Y %H:%M:%S')

checkResult ()
{
    if [ $1 -eq 0 ]; then
        printf "${GREEN}[OK]${COLOR_END}\n"
    else
        printf "${RED}[ERROR]${COLOR_END}\n"
        echo "Check Buildlog in ${LOG_DIR}/"
        echo ""
        exit 1
    fi
}

clear

# create directories initially
[ ! -d ${TMUX_STATIC_HOME} ]         && mkdir ${TMUX_STATIC_HOME}
[ ! -d ${TMUX_STATIC_HOME}/src ]     && mkdir ${TMUX_STATIC_HOME}/src
[ ! -d ${TMUX_STATIC_HOME}/lib ]     && mkdir ${TMUX_STATIC_HOME}/lib
[ ! -d ${TMUX_STATIC_HOME}/bin ]     && mkdir ${TMUX_STATIC_HOME}/bin
[ ! -d ${TMUX_STATIC_HOME}/include ] && mkdir ${TMUX_STATIC_HOME}/include
[ ! -d ${LOG_DIR} ]                  && mkdir ${LOG_DIR}

# Clean up #
printf "${BLUE}Cleaning up...${COLOR_END}\n"
rm -rf ${TMUX_STATIC_HOME}/include/*
rm -rf ${TMUX_STATIC_HOME}/lib/*
rm -rf ${TMUX_STATIC_HOME}/bin/*
rm -rf ${LOG_DIR}/*

rm -rf ${TMUX_STATIC_HOME}/src/upx-${UPX_VERSION}-amd64_linux
rm -rf ${TMUX_STATIC_HOME}/src/musl-${MUSL_VERSION}
rm -rf ${TMUX_STATIC_HOME}/src/libevent-${LIBEVENT_VERSION}-stable
rm -rf ${TMUX_STATIC_HOME}/src/ncurses-${NCURSES_VERSION}
rm -rf ${TMUX_STATIC_HOME}/src/tmux-${TMUX_VERSION}

echo ""
printf "${BLUE}*************************************${COLOR_END}\n"
printf "${BLUE}** Starting to build a static TMUX **${COLOR_END}\n"
printf "${BLUE}*************************************${COLOR_END}\n"

echo ""
echo "HINT:"
echo "In case you are behind a proxy, you can define the http_proxy"
echo "variables to download the necessary files like this:"
printf "${YELLOW}export http_proxy=\"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\"${COLOR_END}\n"
printf "${YELLOW}export https_proxy=\"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\"${COLOR_END}\n"

echo ""
echo "musl ${MUSL_VERSION}"
echo "------------------"

cd ${TMUX_STATIC_HOME}/src
if [ ! -f ${MUSL_ARCHIVE} ]; then
    printf "Downloading..."
    wget -q ${MUSL_URL}/${MUSL_ARCHIVE}
    checkResult $?
fi

printf "Extracting...."
tar xzf ${MUSL_ARCHIVE}
checkResult $?

cd musl-${MUSL_VERSION}

printf "Configuring..."
./configure --enable-gcc-wrapper --disable-shared --prefix=${TMUX_STATIC_HOME} --bindir=${TMUX_STATIC_HOME}/bin --includedir=${TMUX_STATIC_HOME}/include --libdir=${TMUX_STATIC_HOME}/lib > ${LOG_DIR}/musl-${MUSL_VERSION}.log 2>&1
checkResult $?

printf "Compiling....."
make >> ${LOG_DIR}/musl-${MUSL_VERSION}.log 2>&1
checkResult $?

printf "Installing...."
make install >> ${LOG_DIR}/musl-${MUSL_VERSION}.log 2>&1
checkResult $?

export CC="${TMUX_STATIC_HOME}/bin/musl-gcc -static"

echo ""
echo "libevent ${LIBEVENT_VERSION}-stable"
echo "------------------"

cd ${TMUX_STATIC_HOME}/src
if [ ! -f ${LIBEVENT_ARCHIVE} ]; then
    printf "Downloading..."
    wget -q ${LIBEVENT_URL}/${LIBEVENT_ARCHIVE}
    checkResult $?
fi

printf "Extracting...."
tar xzf ${LIBEVENT_ARCHIVE}
checkResult $?

cd libevent-${LIBEVENT_VERSION}-stable

printf "Configuring..."
./configure --prefix=${TMUX_STATIC_HOME} --includedir=${TMUX_STATIC_HOME}/include --libdir=${TMUX_STATIC_HOME}/lib --disable-shared --disable-samples > ${LOG_DIR}/libevent-${LIBEVENT_VERSION}-stable.log 2>&1
checkResult $?

printf "Compiling....."
make >> ${LOG_DIR}/libevent-${LIBEVENT_VERSION}-stable.log 2>&1
checkResult $?

printf "Installing...."
make install >> ${LOG_DIR}/libevent-${LIBEVENT_VERSION}-stable.log 2>&1
checkResult $?

echo ""
echo "ncurses ${NCURSES_VERSION}"
echo "------------------"

cd ${TMUX_STATIC_HOME}/src
if [ ! -f ${NCURSES_ARCHIVE} ]; then
    printf "Downloading..."
    wget -q ${NCURSES_URL}/${NCURSES_ARCHIVE}
    checkResult $?
fi

printf "Extracting...."
tar xzf ${NCURSES_ARCHIVE}
checkResult $?

cd ncurses-${NCURSES_VERSION}

printf "Configuring..."
./configure --prefix=${TMUX_STATIC_HOME} --includedir=${TMUX_STATIC_HOME}/include --libdir=${TMUX_STATIC_HOME}/lib --enable-pc-files --with-pkg-config=${TMUX_STATIC_HOME}/lib/pkgconfig --with-pkg-config-libdir=${TMUX_STATIC_HOME}/lib/pkgconfig --without-ada --without-tests --without-manpages --with-ticlib --with-termlib --with-default-terminfo-dir=/usr/share/terminfo --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo > ${LOG_DIR}/ncurses-${NCURSES_VERSION}.log 2>&1
checkResult $?

printf "Compiling....."
make >> ${LOG_DIR}/ncurses-${NCURSES_VERSION}.log 2>&1
checkResult $?

printf "Installing...."
make install >> ${LOG_DIR}/ncurses-${NCURSES_VERSION}.log 2>&1
checkResult $?

echo ""
echo "tmux ${TMUX_VERSION}"
echo "------------------"

cd ${TMUX_STATIC_HOME}/src
if [ ! -f ${TMUX_ARCHIVE} ]; then
    printf "Downloading..."
    wget -q ${TMUX_URL}/${TMUX_ARCHIVE}
    checkResult $?
fi

printf "Extracting...."
tar xzf ${TMUX_ARCHIVE}
checkResult $?

cd tmux-${TMUX_VERSION}

printf "Configuring..."
./configure --prefix=${TMUX_STATIC_HOME} --enable-static --includedir="${TMUX_STATIC_HOME}/include" --libdir="${TMUX_STATIC_HOME}/lib" CFLAGS="-I${TMUX_STATIC_HOME}/include" LDFLAGS="-L${TMUX_STATIC_HOME}/lib" CPPFLAGS="-I${TMUX_STATIC_HOME}/include" LIBEVENT_LIBS="-L${TMUX_STATIC_HOME}/lib -levent" LIBNCURSES_CFLAGS="-I${TMUX_STATIC_HOME}/include/ncurses" LIBNCURSES_LIBS="-L${TMUX_STATIC_HOME}/lib -lncurses" LIBTINFO_CFLAGS="-I${TMUX_STATIC_HOME}/include/ncurses" LIBTINFO_LIBS="-L${TMUX_STATIC_HOME}/lib -ltinfo" > ${LOG_DIR}/tmux-${TMUX_VERSION}.log 2>&1
checkResult $?

printf "Compiling....."
make >> ${LOG_DIR}/tmux-${TMUX_VERSION}.log 2>&1
checkResult $?

printf "Installing...."
make install >> ${LOG_DIR}/tmux-${TMUX_VERSION}.log 2>&1
checkResult $?

cd ${TMUX_STATIC_HOME}

# strip text from binary
cp ${TMUX_STATIC_HOME}/bin/tmux ${TMUX_STATIC_HOME}/bin/tmux.stripped
printf "Stripping....."
strip ${TMUX_STATIC_HOME}/bin/tmux.stripped
checkResult $?

# compress with upx, when choosen
if [ ! -z ${USE_UPX} ] && [ ${USE_UPX} = "TRUE" ]; then
    echo ""
    echo "Compressing binary with UPX ${UPX_VERSION}"
    echo "--------------------------------"
    cd ${TMUX_STATIC_HOME}/src
    if [ ! -f ${UPX_ARCHIVE} ]; then
        printf "Downloading..."
        wget -q ${UPX_URL}/${UPX_ARCHIVE}
        checkResult $?
    fi
    tar xJf ${UPX_ARCHIVE}
    cd upx-${UPX_VERSION}-amd64_linux
    mv upx ${TMUX_STATIC_HOME}/bin/

    # compress binary with upx
    cp ${TMUX_STATIC_HOME}/bin/tmux.stripped ${TMUX_STATIC_HOME}/bin/tmux.upx
    printf "Compressing..."
    ${TMUX_STATIC_HOME}/bin/upx -q --best --ultra-brute ${TMUX_STATIC_HOME}/bin/tmux.upx > /dev/null 2>&1
    checkResult $?
fi

echo ""
echo "Standard tmux binary:   ${TMUX_STATIC_HOME}/bin/tmux.gz"
echo "Stripped tmux binary:   ${TMUX_STATIC_HOME}/bin/tmux.stripped.gz"

gzip ${TMUX_STATIC_HOME}/bin/tmux
gzip ${TMUX_STATIC_HOME}/bin/tmux.stripped

if [ ! -z ${USE_UPX} ] && [ ${USE_UPX} = "TRUE" ]; then
    echo "Compressed tmux binary: ${TMUX_STATIC_HOME}/bin/tmux.upx.gz"
	gzip ${TMUX_STATIC_HOME}/bin/tmux.upx
fi

echo ""
echo "----------------------------------------"
echo "Start: ${START_TIME}"
echo "End:   $(date '+%d.%m.%Y %H:%M:%S')"
echo ""
