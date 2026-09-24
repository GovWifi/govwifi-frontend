# Installing build dependencies for the GovWifi FreeRADIUS module

Step-by-step guide (tested on this machine) to install **everything** needed to
compile FreeRADIUS 3.2.x + `rlm_govlogger` from source, including the path used
when `sudo` is unavailable (user-local install from official `.deb` packages).

---

## 1. What is required, and why

| Tool / Library            | Purpose in this build |
|---------------------------|-----------------------|
| gcc, make, libc dev       | Compile FreeRADIUS + module |
| autoconf, automake, libtool | Autotools build system of FreeRADIUS 3.2 |
| pkg-config                | Library discovery |
| libjson-c (runtime + dev) | **Mandatory** — `rlm_govlogger` (`json.c`) links `-ljson-c` |
| libtalloc (runtime + dev) | FreeRADIUS core memory allocator |
| libglib2.0 (runtime + dev) | FreeRADIUS core dependency |
| libpcre2-8 (runtime + dev) | Regex support in FreeRADIUS |
| OpenSSL dev headers       | TLS for EAP (`rlm_eap_tls`); system-provided is fine |

> Note: system `gcc`/`make`/`pkg-config`/OpenSSL headers were already present.
> The packages below are only the *missing* pieces; install a superset if you
> are starting from a clean machine.

---

## Path A — standard (sudo available), recommended

```bash
# Ubuntu 22.04 / 24.04
sudo apt-get update
sudo apt-get install -y \
    build-essential gcc g++ make pkg-config \
    autoconf automake libtool \
    libjson-c-dev \
    libtalloc-dev \
    libglib2.0-dev \
    libpcre2-dev \
    libssl-dev
```

Verify:

```bash
autoconf --version && automake --version && libtoolize --version
pkg-config --modversion json-c talloc glib-2.0 libpcre2-8
gcc --version | head -1
```

If `automake` resolves to a wrong version after install, ensure
`$PATH`/perl libs match (rare on stock Ubuntu):

```bash
ls -l $(which automake)
```

You are done — skip to the FreeRADIUS build section.

---

## Path B — sudo-free (user-local install; what was done on this machine)

Download the official Ubuntu `.deb` files and extract them into a local prefix.
No system directories are touched; everything lands under `$HOME/.local`.

### B.1. Download the packages

```bash
mkdir -p /tmp/aptcache/partial

apt-get download \
    -o Dir::Cache=/tmp/aptcache \
    -o Dir::Cache::partial=/tmp/aptcache/partial \
    -o Dir::Arch=amd64 \
    build-essential gcc \
    libjson-c5 libjson-c-dev \
    libtalloc2 libtalloc-dev \
    libglib2.0-0t64 libglib2.0-dev \          # on Noble (24.04); 22.04 uses libglib2.0-0
    libpcre2-8-0 libpcre2-dev \
    autoconf automake libtool \
    pkg-config libssl-dev
```

`libssl-dev`/`gcc` are optional if already provided by the system.

### B.2. Extract into the local prefix

Order matters: runtime libs first, then the `-dev` packages on top (same files,
dev adds headers + `.pc` files).

```bash
P=$HOME/.local
cd /tmp/aptcache

for pkg in \
    libtalloc2*.deb \
    libtalloc-dev*.deb \
    libglib2.0-*.deb \
    libglib2.0-dev*.deb \
    libpcre2-8-0*.deb \
    libpcre2-dev*.deb \
    libjson-c5*.deb \
    libjson-c-dev*.deb \
    autoconf*.deb \
    automake*.deb \
    libtool*.deb \
    pkg-config*.deb
do
    dpkg -x $pkg $P || echo "WARN: failed $pkg"
done

# automake ships as automake-1.16; provide the plain `automake` name
[ -e $P/usr/bin/automake ] || ln -s automake-1.16 $P/usr/bin/automake
```

### B.3. Environment (source before every build)

Saved at `<repo>/local-deps/env.sh` (next to this file):

```bash
# Source this before building FreeRADIUS 3.2.x with the govwifi module:
#   source <module-repo>/local-deps/env.sh
P=$HOME/.local
export PATH="$P/usr/bin:$PATH"
export LD_LIBRARY_PATH="$P/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$P/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH"
export CFLAGS="-I$P/usr/include $CFLAGS"
export LDFLAGS="-L$P/usr/lib/x86_64-linux-gnu $LDFLAGS"
export PERL5LIB="$P/usr/share/automake-1.16${PERL5LIB:+:$PERL5LIB}"
# FreeRADIUS configure needs talloc's lib dir explicitly
export TALLOCLIB="$P/usr/lib/x86_64-linux-gnu"
```

### B.4. Verification (all must pass)

```bash
source <module-repo>/local-deps/env.sh

# Tools
autoconf --version | head -1        # autoconf (GNU Autoconf) 2.71
automake --version | head -1        # automake (GNU automake) 1.16.5
libtoolize --version | head -1      # libtoolize (GNU libtool) 2.4.7

# Libraries
pkg-config --modversion json-c talloc glib-2.0 libpcre2-8

# Compile + link + run against the key libraries
cat > /tmp/deps_test.c <<'EOF'
#include <json-c/json.h>
#include <talloc.h>
#include <glib.h>
#include <stdio.h>
int main(){
    void *ctx = talloc_new(NULL);
    char *s = talloc_strdup(ctx, "hello");
    json_object *o = json_object_new_string(s);
    printf("%s -> %s\n", s, json_object_to_json_string(o));
    json_object_put(o); talloc_free(ctx);
    return 0;
}
EOF
gcc -o /tmp/deps_test /tmp/deps_test.c \
    $(pkg-config --cflags json-c talloc) \
    $(pkg-config --libs glib-2.0) \
    -L$HOME/.local/usr/lib/x86_64-linux-gnu -ljson-c -ltalloc
LD_LIBRARY_PATH=$HOME/.local/usr/lib/x86_64-linux-gnu /tmp/deps_test
# expected: hello -> "hello"
```

> **Gotcha hit during actual build:** FreeRADIUS 3.2's `configure` probes talloc
> with `lt_lib_check([talloc], [_talloc])` which only looks in standard dirs —
> you **must** pass `--with-talloc-lib-dir=<prefix>/usr/lib/x86_64-linux-gnu`.

---

## 2. Build the module (after dependencies are set up)

```bash
source <module-repo>/local-deps/env.sh

cd <module-repo>/build          # build tree lives here (or create a fresh clone)
git clone --depth 1 -b v3.2.x https://github.com/FreeRADIUS/freeradius-server.git freeradius-server
cd freeradius-server

# Overlay the govwifi module sources (module-repo/src)
(cd <module-repo> && tar cf - src) | tar xvf -

# Register the module + its tests with FreeRADIUS's build system
echo rlm_govlogger >> src/modules/stable
sed -E -i 's/^(SUBMAKEFILES .*)/\1 govlogger\/all.mk/' src/tests/all.mk

./configure --sysconfdir=/etc \
    --with-talloc-lib-dir=$TALLOCLIB \
    --without-ruby --without-python --without-perl --without-lua --without-shell

make -j$(nproc)

# Tests (unit tests + log-output diff tests)
make tests.govlogger
```

Expected success output (actual result from the verified build):

```
GOVLOGGER_TEST base.out
GOVLOGGER_TEST checking diffs
GOVLOGGER_TEST Joining govlogger.output and govlogger.output.total into govlogger.output.concatenated
GOVLOGGER_TEST Checking log output
GOVLOGGER_TEST Checking output diffs
```

Artifacts:

```
freeradius-server/build/rlm_govlogger.so   # the module (65 KB)
freeradius-server/build/bin/radiusd        # the server
freeradius-server/build/bin/govlogger_unit # test binary
```

---

## 3. Runtime & production notes

- **Runtime libs**: if built with the sudo-free prefix, set
  `LD_LIBRARY_PATH=$HOME/.local/usr/lib/x86_64-linux-gnu` (or run `ldconfig`
  against it as root) whenever starting `radiusd` — `rlm_govlogger.so`
  dynamically links `libjson-c.so.5`.
- **EAP is required** at runtime: `rlm_govlogger` looks up an `eap` module
  instance during init. If no `eap` module is instantiated the module aborts.
- **mods-enabled layout**: with FreeRADIUS 3.2 the file in
  `mods-enabled/govlogger` must contain the `govlogger { ... }` section inline
  (no `include` line) — unlike the v4-style `raddb/mods-available/govlogger`
  sample that ships with the module repo.
- **EAP-TLS certs**: if you enable `rlm_eap_tls`, generate the certs first:
  `cd freeradius-server/raddb/certs && make -j4 server`
  (single-threaded `make server` is safer for the `server.vrfy` target).
- **Test env**: the module test suite runs
  `$top_builddir/bin/radiusd` with `LD_LIBRARY_PATH=$TALLOCLIB`, so the local
  prefix libs are picked up automatically.

## 4. Cleanup (optional)

```bash
rm -rf /tmp/aptcache /tmp/deps_test /tmp/deps_test.c
```

The usable dependency tree lives in `$HOME/.local`; remove with
`rm -rf $HOME/.local/usr/bin/{autoconf,automake*,libtoolize,...}` etc. if you
want parts of it back out.
