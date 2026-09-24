# syntax=docker/dockerfile:1
#
# Builds FreeRADIUS 3.2.2 + rlm_govlogger (GovWifi custom module) on Alpine 3.22,
# runs the govwifi test suite, and stages the compiled artifacts in /out.

ARG BASE=alpine:3.22

# ---------------------------------------------------------------------------
# Stage 1: builder
# ---------------------------------------------------------------------------
FROM ${BASE} AS builder

ARG FREERADIUS_URL=https://github.com/FreeRADIUS/freeradius-server/releases/download/release_3_2_2/freeradius-server-3.2.2.tar.gz

ENV TZ=Etc/UTC

# --- Dependencies (build tools + FreeRADIUS module requirements) -----------
RUN apk add --no-cache \
        build-base \
        linux-headers \
        coreutils \
        bash \
        autoconf automake libtool pkgconf \
        ca-certificates curl \
        json-c json-c-dev \
        talloc talloc-dev \
        glib glib-dev \
        pcre2 pcre2-dev \
        openssl-dev

WORKDIR /build

# --- FreeRADIUS 3.2.2 source ----------------------------------------------
RUN curl -fSL ${FREERADIUS_URL} -o freeradius.tar.gz \
    && tar -xzf freeradius.tar.gz \
    && mv freeradius-server-* freeradius-server \
    && rm freeradius.tar.gz

# --- Overlay GovWifi module (module-src/ = module repo's src/ + raddb/) ----
COPY build-context/module-src/ ./freeradius-server/module-src/

RUN cd freeradius-server \
    && (cd module-src && tar cf - src) | tar xvf -

# Register the module + its tests with FreeRADIUS's build system
RUN cd freeradius-server \
    && ! grep -q '^rlm_govlogger$' src/modules/stable \
         || echo rlm_govlogger >> src/modules/stable \
    && sed -E -i 's/^(SUBMAKEFILES .*)/\1 govlogger\/all.mk/' src/tests/all.mk

# --- Configure & build ------------------------------------------------------
RUN cd freeradius-server \
    && ./configure --sysconfdir=/etc \
         --without-ruby --without-python --without-perl --without-lua --without-shell \
        && make -j"$(nproc)"

# --- Run the govwifi test suite (unit + log-output diff tests) -------------
RUN cd freeradius-server \
    && make tests.govlogger

# ---------------------------------------------------------------------------
# Stage 2: artifacts
# ---------------------------------------------------------------------------
FROM ${BASE} AS out

# json-c: runtime dep of rlm_govlogger.so, so the extracted bundle is
# self-contained on an otherwise-bare Alpine 3.22 host.
RUN apk add --no-cache json-c

COPY --from=builder /build/freeradius-server/build/lib/.libs/rlm_govlogger.so /out/rlm_govlogger.so
COPY --from=builder /build/freeradius-server/build/bin/govlogger_unit      /out/govlogger_unit
COPY --from=builder /build/freeradius-server/module-src/raddb/mods-available/govlogger \
                                                                  /out/raddb-govlogger.conf.sample
# Runtime lib
RUN set -x \
    && ls -l /out \
    && ldd /out/rlm_govlogger.so \
    && find /usr/lib /lib -name 'libjson-c.so*' || true

# Copy to the host:
#   docker run --rm -v /path/host-dir:/host govwifi-radius cp -r /out/. /host/