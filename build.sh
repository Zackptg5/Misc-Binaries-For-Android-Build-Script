#!/bin/bash
echored () {
	echo "${TEXTRED}$1${TEXTRESET}"
}
echogreen () {
	echo "${TEXTGREEN}$1${TEXTRESET}"
}
usage () {
  echo " "
  echored "USAGE:"
  echogreen "BIN=      (Default: all) (Valid options are: exa, htop, iftop, nethogs, patchelf, sqlite, strace, tcpdump, vim, zsh, zstd)"
  echogreen "ARCH=     (Default: all) (Valid Arch values: all, arm, arm64, aarch64, x86, i686, x64, x86_64)"
  echogreen "STATIC=   (Default: true) (Valid options are: true, false)"
  echogreen "API=      (Default: 30) (Valid options are: 21, 22, 23, 24, 26, 27, 28, 29, 30)"
  echogreen "          Note that Zsh requires API of 24 or higher for gdbm"
  echogreen "           Note that you can put as many of these as you want together as long as they're comma separated"
  echogreen "           Ex: BIN=htop,vim,zsh"
  echo " "
  exit 1
}
build_ncursesw() {
  export NPREFIX="$(echo $PREFIX | sed "s|$LBIN|ncursesw|")"
  [ -d $NPREFIX ] && return 0
	echogreen "Building NCurses wide..."
	cd $DIR
	[ -f "ncursesw-$NVER.tar.gz" ] || wget -O ncursesw-$NVER.tar.gz http://mirrors.kernel.org/gnu/ncurses/ncurses-$NVER.tar.gz
	[ -d ncursesw-$NVER ] || { mkdir ncursesw-$NVER; tar -xf ncursesw-$NVER.tar.gz --transform s/ncurses-$NVER/ncursesw-$NVER/; }
	cd ncursesw-$NVER
	./configure $FLAGS--prefix=$NPREFIX --enable-widec --disable-nls --disable-stripping --host=$target_host --target=$target_host CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
	[ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
	make install
  make distclean
  cd $DIR/$LBIN
}
build_ncurses() {
  export NPREFIX="$(echo $PREFIX | sed "s|$LBIN|ncurses|")"
  [ -d $NPREFIX ] && return 0
	echogreen "Building NCurses..."
	cd $DIR
	[ -f "ncurses-$NVER.tar.gz" ] || wget -O ncurses-$NVER.tar.gz http://mirrors.kernel.org/gnu/ncurses/ncurses-$NVER.tar.gz
	[ -d ncurses-$NVER ] || { mkdir ncurses-$NVER; tar -xf ncurses-$NVER.tar.gz --transform s/ncurses-$NVER/ncurses-$NVER/; }
	cd ncurses-$NVER
	./configure $FLAGS--prefix=$NPREFIX --disable-nls --disable-stripping --host=$target_host --target=$target_host CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
  [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
	make install
  make distclean
  cd $DIR/$LBIN
}
build_zlib() {
  export ZPREFIX="$(echo $PREFIX | sed "s|$LBIN|zlib|")"
  [ -d $ZPREFIX ] && return 0
	cd $DIR
	echogreen "Building ZLib..."
	[ -f "zlib-$ZVER.tar.gz" ] || wget http://zlib.net/zlib-$ZVER.tar.gz
	[ -d zlib-$ZVER ] || tar -xf zlib-$ZVER.tar.gz
	cd zlib-$ZVER
  [ "$1" == "static" ] && ./configure --prefix=$ZPREFIX --static || ./configure --prefix=$ZPREFIX
	[ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
	make install
  make clean
	cd $DIR/$LBIN
}
build_bzip2() {
  export BPREFIX="$(echo $PREFIX | sed "s|$LBIN|bzip2|")"
  rm -rf $BPREFIX 2>/dev/null
	echogreen "Building BZip2..."
  cd $DIR
	[ -f "bzip2-latest.tar.gz" ] || wget https://www.sourceware.org/pub/bzip2/bzip2-latest.tar.gz
	tar -xf bzip2-latest.tar.gz
	cd bzip2-[0-9]*
	sed -i -e '/# To assist in cross-compiling/,/LDFLAGS=/d' -e "s/CFLAGS=/CFLAGS=$CFLAGS /" -e 's/bzip2recover test/bzip2recover/' Makefile
	export LDFLAGS
	make -j$JOBS
	export -n LDFLAGS
	[ $? -eq 0 ] || { echored "Bzip2 build failed!"; exit 1; }
	make install -j$JOBS PREFIX=$BPREFIX
  make distclean
	cd $DIR/$LBIN
}
build_pcre() {
  export PPREFIX="$(echo $PREFIX | sed "s|$LBIN|pcre|")"
  [ -d $PPREFIX ] && return 0
	build_zlib
	build_bzip2
  cd $DIR
	echogreen "Building PCRE..."
	[ -f "pcre-$PVER.tar.bz2" ] || wget https://ftp.pcre.org/pub/pcre/pcre-$PVER.tar.bz2
	[ -d pcre-$PVER ] || tar -xf pcre-$PVER.tar.bz2
	cd pcre-$PVER
	$STATIC && local FLAGS="--disable-shared $FLAGS"
  ./configure $FLAGS--prefix= \
              --enable-unicode-properties \
              --enable-jit \
              --enable-pcregrep-libz \
              --enable-pcregrep-libbz2 \
              --host=$target_host \
              --target=$target_host \
              CFLAGS="$CFLAGS -I$ZPREFIX/include -I$BPREFIX/include" \
              LDFLAGS="$LDFLAGS -L$ZPREFIX/lib -L$BPREFIX/lib"
	[ $? -eq 0 ] || { echored "PCRE configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "PCRE build failed!"; exit 1; }
	make install -j$JOBS DESTDIR=$PPREFIX
  make distclean
	cd $DIR/$LBIN
  $STATIC || install -D $PPREFIX/lib/libpcre.so $PREFIX/lib/libpcre.so
}
build_gdbm() {
  export GPREFIX="$(echo $PREFIX | sed "s|$LBIN|gdbm|")"
  [ -d $GPREFIX ] && return 0
	echogreen "Building Gdbm..."
  cd $DIR
	[ -f "gdbm-latest.tar.gz" ] || wget http://mirrors.kernel.org/gnu/gdbm/gdbm-latest.tar.gz
	[[ -d "gdbm-"[0-9]* ]] || tar -xf gdbm-latest.tar.gz
	cd gdbm-[0-9]*
	$STATIC && local FLAGS="--disable-shared $FLAGS"
	./configure $FLAGS--prefix= \
              --disable-nls \
              --host=$target_host \
              --target=$target_host \
              CFLAGS="$CFLAG" \
              LDFLAGS="$LDFLAGS"
	[ $? -eq 0 ] || { echored "Gdbm configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Gdbm build failed!"; exit 1; }
	make install -j$JOBS DESTDIR=$GPREFIX
  make distclean
	cd $DIR/$LBIN
  $STATIC || install -D $GPREFIX/lib/libgdbm.so $PREFIX/lib/libgdbm.so.6
}
setup_ohmyzsh() {
  local OPREFIX="$(echo $PREFIX | sed "s|$LBIN|ohmyzsh|")"
  [ -d $PREFIX/system/etc/zsh ] && return 0
  cd $DIR
  mkdir -p $OPREFIX
  git clone https://github.com/ohmyzsh/ohmyzsh.git $OPREFIX/.oh-my-zsh
  cd $OPREFIX
  cp $OPREFIX/.oh-my-zsh/templates/zshrc.zsh-template .zshrc
  sed -i -e "s|PATH=.*|PATH=\$PATH|" -e "s|ZSH=.*|ZSH=/system/etc/zsh/.oh-my-zsh|" -e "s|ARCHFLAGS=.*|ARCHFLAGS=\"-arch $LARCH\"|" .zshrc
  cd $DIR/$LBIN
  mkdir -p $PREFIX/system/etc/zsh
  cp -rf $OPREFIX/.oh-my-zsh $PREFIX/system/etc/zsh/
  cp -f $OPREFIX/.zshrc $PREFIX/system/etc/zsh/.zshrc
}
build_libpcap() {
  export LPREFIX="$(echo $PREFIX | sed "s|$LBIN|libpcap|")"
  [ -d $LPREFIX ] && return 0
  echogreen "Building libpcap..."
  cd $DIR
  rm -rf libpcap-$LVER
  # [ -f "libpcap-$LVER.tar.gz" ] || wget -O libpcap-$LVER.tar.gz https://www.tcpdump.org/release/libpcap-$LVER.tar.gz
  # tar -xf libpcap-$LVER.tar.gz
  git clone https://android.googlesource.com/platform/external/libpcap # Switch to google repo cause it just works
  mv -f libpcap libpcap-$LVER
  cd libpcap-$LVER
  $STATIC && local FLAGS="--disable-shared $FLAGS"
  ./configure $FLAGS--prefix=$LPREFIX --with-pcap=linux --without-libnl --host=$target_host --target=$target_host CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
  [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
  make -j$JOBS
  [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
  make install -j$JOBS
  cp -rf $DIR/libpcap-$LVER/* $LPREFIX/
  make distclean
  cd $DIR/$LBIN
}
build_readline() {
  export RPREFIX="$(echo $PREFIX | sed "s|$LBIN|readline|")"
  [ -d $RPREFIX ] && return 0
	echogreen "Building libreadline..."
  cd $DIR
	[ -f "readline-$RVER.tar.gz" ] || wget http://mirrors.kernel.org/gnu/readline/readline-$RVER.tar.gz
	[ -d "readline-$RVER" ] || tar -xf readline-$RVER.tar.gz
	cd readline-$RVER
	$STATIC && local FLAGS="--disable-shared $FLAGS"
	./configure $FLAGS--prefix=$RPREFIX \
              --host=$target_host \
              --target=$target_host \
              CFLAGS="$CFLAG" \
              LDFLAGS="$LDFLAGS"
	[ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
	make install -j$JOBS
  make distclean
	cd $DIR/$LBIN
}
build_openssl() {
  # build_zlib - causes errors later down the line during tcpdump compile
  export OPREFIX="$(echo $PREFIX | sed "s|$LBIN|openssl|")"
  [ -d $OPREFIX ] && return 0
  cd $DIR
  echogreen "Building Openssl..."
  [ -d openssl ] && cd openssl || { git clone https://github.com/openssl/openssl; cd openssl; git checkout OpenSSL_$OVER; }
  if $STATIC; then
    sed -i "/#if \!defined(_WIN32)/,/#endif/d" fuzz/client.c
    sed -i "/#if \!defined(_WIN32)/,/#endif/d" fuzz/server.c
    # local FLAGS=" no-shared zlib $FLAGS"
    local FLAGS=" no-shared $FLAGS"
  else
    # local FLAGS=" shared zlib-dynamic $FLAGS"
    local FLAGS=" shared $FLAGS"
  fi
  ./Configure $OSARCH$FLAGS \
              -D__ANDROID_API__=$API \
              --prefix=$OPREFIX #\
              # --with-zlib-include=$ZPREFIX/include \
              # --with-zlib-lib=$ZPREFIX/lib
  [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
  make -j$JOBS
  [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
  make install_sw
  make distclean
  cd $DIR/$LBIN
}

TEXTRESET=$(tput sgr0)
TEXTGREEN=$(tput setaf 2)
TEXTRED=$(tput setaf 1)
DIR=$PWD
NDKVER=r21e
STATIC=true
OIFS=$IFS; IFS=\|;
while true; do
  case "$1" in
    -h|--help) usage;;
    "") shift; break;;
    API=*|STATIC=*|BIN=*|ARCH=*) eval $(echo "$1" | sed -e 's/=/="/' -e 's/$/"/' -e 's/,/ /g'); shift;;
    *) echored "Invalid option: $1!"; usage;;
  esac
done
IFS=$OIFS
[ -z "$ARCH" -o "$ARCH" == "all" ] && ARCH="arm arm64 x86 x64"
[ -z "$BIN" -o "$BIN" == "all" ] && BIN="htop patchelf strace vim zsh"

case $API in
  21|22|23|24|26|27|28|29|30) ;;
  *) API=30;;
esac

if [ -f /proc/cpuinfo ]; then
  JOBS=$(grep flags /proc/cpuinfo | wc -l)
elif [ ! -z $(which sysctl) ]; then
  JOBS=$(sysctl -n hw.ncpu)
else
  JOBS=2
fi

# Set up Android NDK
echogreen "Fetching Android NDK $NDKVER"
[ -f "android-ndk-$NDKVER-linux-x86_64.zip" ] || wget https://dl.google.com/android/repository/android-ndk-$NDKVER-linux-x86_64.zip
[ -d "android-ndk-$NDKVER" ] || unzip -qo android-ndk-$NDKVER-linux-x86_64.zip
export ANDROID_NDK_HOME=$DIR/android-ndk-$NDKVER
export ANDROID_TOOLCHAIN=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin
export PATH=$ANDROID_TOOLCHAIN:$PATH
# Create needed symlinks
for i in armv7a-linux-androideabi aarch64-linux-android x86_64-linux-android i686-linux-android; do
  [ "$i" == "armv7a-linux-androideabi" ] && j="arm-linux-androideabi" || j=$i
  ln -sf $ANDROID_TOOLCHAIN/$i$API-clang $ANDROID_TOOLCHAIN/$j-clang
  ln -sf $ANDROID_TOOLCHAIN/$i$API-clang++ $ANDROID_TOOLCHAIN/$j-clang++
  ln -sf $ANDROID_TOOLCHAIN/$i$API-clang $ANDROID_TOOLCHAIN/$j-gcc
  ln -sf $ANDROID_TOOLCHAIN/$i$API-clang++ $ANDROID_TOOLCHAIN/$j-g++
done
for i in ar as ld ranlib strip clang gcc clang++ g++; do
  ln -sf $ANDROID_TOOLCHAIN/arm-linux-androideabi-$i $ANDROID_TOOLCHAIN/arm-linux-gnueabi-$i
  ln -sf $ANDROID_TOOLCHAIN/i686-linux-android-$i $ANDROID_TOOLCHAIN/i686-linux-gnu-$i
done
if [ -d ~/.cargo ]; then
  [ -f ~/.cargo/config.bak ] || cp -f ~/.cargo/config ~/.cargo/config.bak
  cp -f $DIR/config ~/.cargo/config
  sed -i "s|<ANDROID_TOOLCHAIN>|$ANDROID_TOOLCHAIN|g" ~/.cargo/ 2>/dev/null
fi

LVER=1.10
NVER=6.2
OVER=1_1_1i
PVER=8.43
RVER=8.0
ZVER=1.2.11
for LBIN in $BIN; do
  case $LBIN in
    "exa") VER="v0.9.0"; URL="ogham/exa"
           [ $API -lt 24 ] && API=24;;
    "htop") VER="3.0.4"; URL="htop-dev/htop"
            [ $API -lt 25 ] && { $STATIC || API=25; };;
    "iftop") VER="0.17"; VER="1.0pre4";
             [ $API -lt 23 ] && API=28;;
    "nethogs") VER="v0.8.6"; URL="raboof/nethogs";;
    "patchelf") VER="0.12"; URL="NixOS/patchelf";;
    "sqlite") VER="3340000";;
    "strace") VER="v5.10"; URL="strace/strace";; # Recommend v5.5 for arm64
    "tcpdump") VER="tcpdump-4.99.0"; URL="the-tcpdump-group/tcpdump";;
    "vim") unset VER; URL="vim/vim";;
    "zsh") VER="5.8";;
    "zstd") VER="v1.4.8"; URL="facebook/zstd";;
    *) echored "Invalid binary specified!"; usage;;
  esac

  echogreen "Fetching $LBIN"
  cd $DIR
  rm -rf $LBIN

  case $LBIN in
  "iftop")
    [ -f "iftop-$VER.tar.gz" ] || wget http://www.ex-parrot.com/pdw/iftop/download/iftop-$VER.tar.gz
    tar -xf iftop-$VER.tar.gz --transform s/iftop-$VER/iftop/
    cd $LBIN
    ;;
  "sqlite") 
    [ -f "sqlite-autoconf-$VER.tar.gz" ] || wget https://sqlite.org/2020/sqlite-autoconf-$VER.tar.gz
    tar -xf sqlite-autoconf-$VER.tar.gz --transform s/sqlite-autoconf-$VER/sqlite/
    cd $LBIN
    ;;
  "zsh") 
    [ -f "zsh-$VER.tar.xz" ] || wget -O zsh-$VER.tar.xz https://sourceforge.net/projects/zsh/files/zsh/$VER/zsh-$VER.tar.xz/download
    tar -xf zsh-$VER.tar.xz --transform s/zsh-$VER/zsh/
    cd $LBIN
    ;;
  *)
    git clone https://github.com/$URL
    cd $LBIN
    [ "$VER" ] && git checkout $VER 2>/dev/null
    ;;
  esac

  for LARCH in $ARCH; do
    echogreen "Compiling $LBIN version $VER for $LARCH"
    unset FLAGS
    case $LARCH in
      arm64) LARCH=aarch64; target_host=aarch64-linux-android; OSARCH=android-arm64;;
      arm) LARCH=arm; target_host=arm-linux-androideabi; OSARCH=android-arm;;
      x64) LARCH=x86_64; target_host=x86_64-linux-android; OSARCH=android-x86_64;;
      x86) LARCH=i686; target_host=i686-linux-android; OSARCH=android-x86; FLAGS="TIME_T_32_BIT_OK=yes ";;
      *) echored "Invalid ARCH: $LARCH!"; exit 1;;
    esac
    export AR=$target_host-ar
    export AS=$target_host-as
    export LD=$target_host-ld
    export RANLIB=$target_host-ranlib
    export STRIP=$target_host-strip
    export CC=$target_host-clang
    export CXX=$target_host-clang++
    if $STATIC; then
      CFLAGS='-static -O2'
      LDFLAGS='-static'
      export PREFIX=$DIR/build-static/$LBIN/$LARCH
    else
      CFLAGS='-O2 -fPIE -fPIC'
      LDFLAGS='-s -pie'
      export PREFIX=$DIR/build-dynamic/$LBIN/$LARCH
    fi

    case $LBIN in 
      "exa")
        build_zlib
        cargo b --release --target $target_host -j $JOBS
        [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
        mkdir -p $PREFIX/bin
        cp -f $DIR/exa/target/$target_host/release/exa $PREFIX/bin/exa
      ;;
      "htop")
        build_ncursesw
        ./autogen.sh
        ./configure CFLAGS="$CFLAGS -I$NPREFIX/include" LDFLAGS="$LDFLAGS -L$NPREFIX/lib" --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --enable-proc \
        --enable-unicode \
        ac_cv_lib_ncursesw6_addnwstr=yes
        sed -i "/rdynamic/d" Makefile.am
        ;;
      "iftop")
        build_libpcap
        build_ncurses
        # Cause this binary's old make what's essentially a symlink for each
        echo '#include <ncurses/curses.h>' > $NPREFIX/include/ncurses.h
        cp -f $NPREFIX/include/ncurses.h $NPREFIX/include/curses.h
        if [ ! "$(grep 'Bpthread.h' iftop.c)" ]; then
          # Can't detect pthread from ndk so clear any values set by configure
          sed -i '/test $thrfail = 1/ithrfail=0\nCFLAGS="$oldCFLAGS"\nLIBS="$oldLIBS"' configure
          # pthread_cancel not in ndk, use Hax4us workaround found here: https://github.com/axel-download-accelerator/axel/issues/150
          cp -f $DIR/Bpthread.h Bpthread.h
          sed -i '/pthread.h/a#include <Bpthread.h>' iftop.c
        fi
        ./configure CFLAGS="$CFLAGS -I$LPREFIX/include -I$NPREFIX/include" LDFLAGS="$LDFLAGS -L$LPREFIX/lib -L$NPREFIX/lib" --host=$target_host --target=$target_host \
        --with-libpcap=$LPREFIX --with-resolver=netdb \
        $FLAGS--prefix=$PREFIX
        ;;
      "nethogs")
        build_libpcap
        build_ncurses
        # Same as with iftop...
        echo '#include <ncurses/curses.h>' > $NPREFIX/include/ncurses.h
        # Configure Makefile with proper flags/variables
        sed -i "1aexport PREFIX := $PREFIX\nexport CFLAGS := $CFLAGS -I$LPREFIX/include -I$NPREFIX/include\nexport CXXFLAGS := \${CFLAGS}\nexport LDFLAGS := $LDFLAGS -L$LPREFIX/lib -L$NPREFIX/lib" Makefile
        sed -i "s/decpcap_test test/decpcap_test/g" Makefile
        ;;
      "patchelf")
        ./bootstrap.sh
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
      "sqlite")
        build_zlib
        build_ncurses
        build_readline
	      $STATIC && FLAGS="--disable-shared $FLAGS"
        ./configure --enable-readline \
        CFLAGS="$CFLAGS -I$ZPREFIX/include -I$NPREFIX/include -I$RPREFIX/include" \
        LDFLAGS="$LDFLAGS -L$ZPREFIX/lib -L$NPREFIX/lib -L$RPREFIX/lib" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
      "strace")
        case $LARCH in
          "x86_64") FLAGS="--enable-mpers=m32 $FLAGS";;
          "aarch64") [ $(echo "$VER > 5.5" | bc -l) -eq 1 ] && FLAGS="--enable-mpers=mx32 $FLAGS";; #mpers-m32 errors since v5.6
        esac
        ./bootstrap.sh
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
      "tcpdump")
        build_openssl
        build_libpcap
        ./configure CFLAGS="$CFLAGS -I$LPREFIX/include -I$OPREFIX/include" LDFLAGS="$LDFLAGS -L$LPREFIX/lib -L$OPREFIX/lib" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
      "vim")
        build_ncursesw
        ./configure CFLAGS="$CFLAGS -I$NPREFIX/include" LDFLAGS="$LDFLAGS -L$NPREFIX/lib" --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --disable-nls \
        --with-tlib=ncursesw \
        --without-x \
        --with-compiledby=Zackptg5 \
        --enable-gui=no \
        --enable-multibyte \
        --enable-terminal \
        ac_cv_sizeof_int=4 \
        vim_cv_getcwd_broken=no \
        vim_cv_memmove_handles_overlap=yes \
        vim_cv_stat_ignores_slash=yes \
        vim_cv_tgetent=zero \
        vim_cv_terminfo=yes \
        vim_cv_toupper_broken=no \
        vim_cv_tty_group=world
        ;;
      "zsh")
        build_pcre
        build_gdbm
        build_ncursesw
        setup_ohmyzsh
        sed -i "/exit 0/d" Util/preconfig
        . Util/preconfig
        sed -i -e "/trap 'save=0'/azdmsg=$zd\nmkdir -p $zd" -e "/# Substitute an initial/,/# Don't run if we can't write to \$zd./d" Functions/Newuser/zsh-newuser-install
        $STATIC && FLAGS="--disable-dynamic --disable-dynamic-nss $FLAGS"
        ./configure \
        --host=$target_host --target=$target_host \
        --enable-cflags="$CFLAGS -I $PPREFIX/include -I$GPREFIX/include -I$NPREFIX/include" \
        --enable-ldflags="$LDFLAGS -L$PPREFIX/lib -L$GPREFIX/lib -L$NPREFIX/lib" \
        $FLAGS--prefix=/system \
        --bindir=/system/bin \
        --datarootdir=/system/usr/share \
        --disable-restricted-r \
        --disable-runhelpdir \
        --enable-zshenv=/system/etc/zsh/zshenv \
        --enable-zprofile=/system/etc/zsh/zprofile \
        --enable-zlogin=/system/etc/zsh/zlogin \
        --enable-zlogout=/system/etc/zsh/zlogout \
        --enable-multibyte \
        --enable-pcre \
        --enable-site-fndir=/system/usr/share/zsh/functions \
        --enable-fndir=/system/usr/share/zsh/functions \
        --enable-function-subdirs \
        --enable-scriptdir=/system/usr/share/zsh/scripts \
        --enable-site-scriptdir=/system/usr/share/zsh/scripts \
        --enable-etcdir=/system/etc \
        --libexecdir=/system/bin \
        --sbindir=/system/bin \
        --sysconfdir=/system/etc
        ;;
      "zstd")
        $STATIC && [ ! "$(grep '#Zackptg5' programs/Makefile)" ] && sed -i "s/CFLAGS   +=/CFLAGS   += -static/" programs/Makefile
        [ "$(grep '#Zackptg5' programs/Makefile)" ] || echo "#Zackptg5" >> programs/Makefile
        true # Needed for conditional below in dynamic builds
        ;;
    esac
    [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }

    if [ "$LBIN" != "exa" ]; then
      make -j$JOBS
      [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
      if [ "$LBIN" == "zsh" ]; then
        make install -j$JOBS DESTDIR=$PREFIX
        ! $STATIC && [ "$LBIN" == "zsh" ] && [ "$LARCH" == "aarch64" -o "$LARCH" == "x86_64" ] && mv -f $DEST/$LARCH/lib $DEST/$LARCH/lib64
      else
        make install -j$JOBS
      fi
      make distclean 2>/dev/null || make clean 2>/dev/null
      git reset --hard 2>/dev/null
    fi
    $STRIP $PREFIX/*bin/*
    echogreen "$LBIN built sucessfully and can be found at: $PREFIX"
  done
done
[ -d ~/.cargo ] && [ ! -f ~/.cargo/config.bak ] && cp -f ~/.cargo/config.bak ~/.cargo/config
