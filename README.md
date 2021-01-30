# Misc Binaries for Android Build Script

This will be any of the following binaries using Android NDK:<br/>
exa, htop, iftop, nethogs, patchelf, sqlite3, strace, tcpdump, vim, zsh, zstd<br/>

## Prerequisites

Linux

autoconf, yodl, git, build-essential, gcc-multilib, rust, libgit2, cmake

### To Install rust
```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustup target add aarch64-linux-android arm-linux-androideabi i686-linux-android x86_64-linux-android
```

## Usage

```
bash
git clone https://github.com/Zackptg5/Misc-Binaries-For-Android-Build-Script.git
cd Misc-Binaries-For-Android-Build-Script
chmod +x ./build.sh
./build.sh
```

## Issues
* Sqlite3 static compile still ends up dynamically linked somehow
* Exa static compile still ends up dynamically linked somehow

## Credits

* [Exa](https://github.com/ogham/exa)
* [Htop](https://github.com/hishamhm/htop)
* [Iftop](https://www.ex-parrot.com/pdw/iftop)
* [Nethogs](https://github.com/raboof/nethogs)
* [NixOS](https://github.com/NixOS/patchelf)
* [OhMyZsh](https://ohmyz.sh)
* [Partcyborg](https://github.com/partcyborg/zsh_arm64_magisk)
* [Sqlite3](https://sqlite.org/index.html)
* [Strace](https://github.com/strace/strace)
* [Tcpdump](https://www.tcpdump.org)
* [Vim](https://github.com/vim/vim)
* [Zsh](https://www.zsh.org)
* [Zstd](https://github.com/facebook/zstd)
  
## License

  MIT
