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
  echogreen "BIN=      (Default: all) (Valid options are: htop, patchelf, sqlite, strace, vim, zsh, zstd)"
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
build_zlib() {
  export ZPREFIX="$(echo $PREFIX | sed "s|$LBIN|zlib|")"
	echogreen "Building ZLib..."
  cd $DIR
	[ -f "zlib-$ZVER.tar.gz" ] || wget http://zlib.net/zlib-$ZVER.tar.gz
	[ -d zlib-$ZVER ] || tar -xf zlib-$ZVER.tar.gz
	cd zlib-$ZVER
	./configure --prefix=$ZPREFIX
	[ $? -eq 0 ] || { echored "Zlib configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Zlib build failed!"; exit 1; }
	make install
  make distclean
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

TEXTRESET=$(tput sgr0)
TEXTGREEN=$(tput setaf 2)
TEXTRED=$(tput setaf 1)
DIR=$PWD
NDKVER=r21d
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
# MinAPI for htop is 25

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

NVER=6.2
PVER=8.43
ZVER=1.2.11
for LBIN in $BIN; do
  case $LBIN in
    "htop") VER="3.0.1"; URL="htop-dev/htop/";;
    "patchelf") VER="0.10"; URL="NixOS/patchelf";;
    "sqlite") VER="3330000";;
    "strace") VER="v5.5"; URL="strace/strace";;
    "vim") unset VER; URL="vim/vim";;
    "zsh") VER="5.8";;
    "zstd") VER="v1.4.5"; URL="facebook/zstd";;
    *) echored "Invalid binary specified!"; usage;;
  esac

  echogreen "Fetching $LBIN"
  cd $DIR
  rm -rf $LBIN

  case $LBIN in
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

  case $LBIN in
    "htop") ./autogen.sh;;
    "patchelf") ./bootstrap.sh;;
    "strace") ./bootstrap;;
  esac

  for LARCH in $ARCH; do
    echogreen "Compiling $LBIN version $VER for $LARCH"
    unset FLAGS
    case $LARCH in
      arm64) LARCH=aarch64; target_host=aarch64-linux-android;;
      arm) LARCH=arm; target_host=arm-linux-androideabi;;
      x64) LARCH=x86_64; target_host=x86_64-linux-android;;
      x86) LARCH=i686; target_host=i686-linux-android; FLAGS="TIME_T_32_BIT_OK=yes ";;
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
      "htop")
        build_ncursesw
        ./configure CFLAGS="$CFLAGS -I$NPREFIX/include" LDFLAGS="$LDFLAGS -L$NPREFIX/lib" --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --enable-proc \
        --enable-unicode \
        ac_cv_lib_ncursesw6_addnwstr=yes
        sed -i "/rdynamic/d" Makefile.am
        ;;
      "patchelf")
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
      "sqlite")
        build_zlib
        ./configure CFLAGS="$CFLAGS -I$ZPREFIX/include" LDFLAGS="$LDFLAGS -L$ZPREFIX/lib" --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
      "strace")
        case $LARCH in
          "x86_64") FLAGS="--enable-mpers=m32 $FLAGS";;
          # "aarch64") FLAGS="--enable-mpers=mx32 $FLAGS";; #mpers-m32 errors since v5.6, uncomment this if using compiling strace 5.6+
        esac
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --host=$target_host --target=$target_host \
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
        [ "$(grep '#Zackptg5' programs/Makefile)" ] && echo "#Zackptg5" >> programs/Makefile
        $STATIC && [ ! "$(grep '#Zackptg5' programs/Makefile)" ] && sed -i "s/CFLAGS  +=/CFLAGS  += -static/" programs/Makefile
        true # Needed for conditional below in dynamic builds
        ;;
    esac
    [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }

    make -j$JOBS
    [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
    if [ "$LBIN" == "zsh" ]; then
      make install -j$JOBS DESTDIR=$PREFIX
      ! $STATIC && [ "$LARCH" == "aarch64" -o "$LARCH" == "x86_64" ] && mv -f $DEST/$LARCH/lib $DEST/$LARCH/lib64
    else
      make install -j$JOBS
    fi
    make distclean || make clean
    $STRIP $PREFIX/bin/*
    echogreen "$LBIN built sucessfully and can be found at: $PREFIX"
  done
done