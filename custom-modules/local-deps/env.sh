# Source this before building FreeRADIUS 3.2.x with the govwifi module:
#   source <module-repo>/local-deps/env.sh
#
# User-local (sudo-free) toolchain + build libraries extracted from official
# Ubuntu .debs into $HOME/.local
P=$HOME/.local
export PATH="$P/usr/bin:$PATH"
export LD_LIBRARY_PATH="$P/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$P/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH"
export CFLAGS="-I$P/usr/include $CFLAGS"
export LDFLAGS="-L$P/usr/lib/x86_64-linux-gnu $LDFLAGS"
export PERL5LIB="$P/usr/share/automake-1.16${PERL5LIB:+:$PERL5LIB}"
# Point FreeRADIUS at the local talloc lib (configure needs this explicitly)
export TALLOCLIB="$P/usr/lib/x86_64-linux-gnu"
