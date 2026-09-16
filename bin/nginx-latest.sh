#!/usr/bin/env bash
#
# Discover the newest nginx version this image can actually ship, plus every
# pin that has to move with it.
#
# The ceiling is NOT nginx.org/download. This image installs the *prebuilt*
# nginx-module-otel .apk from nginx.org's Alpine repo, and nginx refuses to
# load a dynamic module whose version differs from its own
# (src/core/ngx_module.c); --with-compat does not exempt that check. So the
# shippable nginx versions are exactly those that have an otel apk built for
# BOTH architectures we publish -- and the Alpine base must be the release
# that apk was built against.
#
# The other three modules are compiled from source, so no index can tell us
# whether they fit; only ./configure && make can. This script reports their
# latest versions, the build is what validates them.
#
# Usage:
#   bin/nginx-latest.sh            # newest shippable version overall
#   bin/nginx-latest.sh 1.28       # newest shippable version in the 1.28 series
#
# Prints sourceable KEY=value lines on stdout, a human summary on stderr.

set -euo pipefail

REPO="https://nginx.org/packages/alpine"
DOWNLOAD="https://nginx.org/download"
ARCHES="x86_64 aarch64"
SERIES="${1:-}"

if [ -n "$SERIES" ] && ! printf '%s' "$SERIES" | grep -qE '^[0-9]+\.[0-9]+$'; then
    echo "error: series must look like MAJOR.MINOR (e.g. 1.28), got '$SERIES'" >&2
    exit 2
fi

fetch() { curl -sfSL --retry 3 --retry-delay 2 "$1"; }

say() { printf '%s\n' "$*" >&2; }

# --- 1. otel apk matrix: which (nginx, alpine) pairs exist on every arch -----

say "Scanning nginx.org Alpine repo for nginx-module-otel builds..."

alpine_releases=$(fetch "$REPO/" | grep -oE 'v3\.[0-9]+' | sort -Vur || true)
[ -n "$alpine_releases" ] || { echo "error: could not list $REPO/" >&2; exit 1; }

matrix=$(mktemp); trap 'rm -f "$matrix"' EXIT

for alpine in $alpine_releases; do
    common=""
    for arch in $ARCHES; do
        listing=$(fetch "$REPO/$alpine/main/$arch/" 2>/dev/null || true)
        found=$(printf '%s' "$listing" \
            | grep -oE 'nginx-module-otel-[0-9]+(\.[0-9]+)+-r[0-9]+\.apk' \
            | sort -u || true)
        [ -n "$found" ] || { common=""; break; }
        if [ -z "$common" ]; then
            common="$found"
        else
            # intersect on the full filename: same nginx version AND same -r
            common=$(comm -12 <(printf '%s\n' "$common") <(printf '%s\n' "$found") || true)
        fi
    done
    [ -n "$common" ] || continue
    while read -r apk; do
        [ -n "$apk" ] || continue
        nv=$(printf '%s' "$apk" | sed -E 's/^nginx-module-otel-([0-9]+\.[0-9]+\.[0-9]+)\..*/\1/')
        printf '%s %s %s\n' "$nv" "${alpine#v}" "$apk" >> "$matrix"
    done <<< "$common"
done

[ -s "$matrix" ] || { echo "error: no otel packages found for arches: $ARCHES" >&2; exit 1; }

# Highest Alpine wins per nginx version (ascending sort, last write survives).
pairs=$(sort -V -k1,1 -k2,2 "$matrix" \
    | awk '{ alpine[$1]=$2; apk[$1]=$3 } END { for (v in alpine) print v, alpine[v], apk[v] }' \
    | sort -Vr)

# --- 2. narrow to the requested series, keep only versions with a tarball ----

candidates=$(printf '%s\n' "$pairs" | awk '{print $1}')
if [ -n "$SERIES" ]; then
    candidates=$(printf '%s\n' "$candidates" | grep -E "^${SERIES//./\\.}\." || true)
    if [ -z "$candidates" ]; then
        say ""
        say "No nginx-module-otel build exists for the $SERIES series on both arches."
        say "Series that are available:"
        printf '%s\n' "$pairs" | awk '{print $1}' | awk -F. '{print $1"."$2}' \
            | sort -Vur | sed 's/^/  /' >&2
        exit 1
    fi
fi

say "Listing nginx source releases..."
releases=$(fetch "$DOWNLOAD/" \
    | grep -oE 'nginx-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' \
    | sed 's/^nginx-//; s/\.tar\.gz$//' | sort -Vu || true)
[ -n "$releases" ] || { echo "error: could not list $DOWNLOAD/" >&2; exit 1; }

chosen=""
for v in $candidates; do
    if printf '%s\n' "$releases" | grep -qxF "$v"; then chosen="$v"; break; fi
    say "  skipping $v: otel has it but nginx.org has no source tarball for $v"
done
[ -n "$chosen" ] || { echo "error: no candidate had a downloadable source tarball" >&2; exit 1; }

# How far behind upstream does the otel ceiling leave us? Worth printing every
# run: the cap moves when nginx.org publishes a new otel apk, which is not
# announced anywhere, so an invisible ceiling is one nobody notices lifting.
upstream_latest=$(printf '%s\n' "$releases" | tail -1)
chosen_series="${chosen%.*}"
upstream_in_series=$(printf '%s\n' "$releases" \
    | grep -E "^${chosen_series//./\\.}\." | tail -1 || true)

row=$(printf '%s\n' "$pairs" | awk -v v="$chosen" '$1==v {print; exit}')
alpine_version=$(printf '%s' "$row" | awk '{print $2}')
otel_apk=$(printf '%s' "$row" | awk '{print $3}')

# --- 3. release signing key: read it off the signature, never hardcode -------
# nginx rotates signers per release (1.26.x pluknet, some 1.30.x arut).

say "Reading the signing key off nginx-$chosen.tar.gz.asc..."
gpg_key=$(fetch "$DOWNLOAD/nginx-$chosen.tar.gz.asc" \
    | gpg --list-packets 2>/dev/null \
    | sed -n 's/.*issuer fpr v4 \([0-9A-F]\{40\}\).*/\1/p' \
    | head -1)
[ -n "$gpg_key" ] || { echo "error: could not extract signing key for $chosen" >&2; exit 1; }

# --- 4. from-source modules: newest released version, via ls-remote ----------
# git ls-remote has no API rate limit, unlike api.github.com.

latest_tag() {
    git ls-remote --tags --refs "$1" 2>/dev/null \
        | sed 's#.*refs/tags/##' | sed 's/^v//' \
        | grep -E '^[0-9]+(\.[0-9]+)+$' | sort -V | tail -1
}

say "Checking from-source module releases..."
headers_more=$(latest_tag https://github.com/openresty/headers-more-nginx-module.git)
fancyindex=$(latest_tag https://github.com/aperezdc/ngx-fancyindex.git)
subs_commit=$(git ls-remote https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git HEAD 2>/dev/null | cut -f1)

[ -n "$headers_more" ] || { echo "error: could not resolve headers-more version" >&2; exit 1; }
[ -n "$fancyindex" ]   || { echo "error: could not resolve fancyindex version" >&2; exit 1; }
[ -n "$subs_commit" ]  || { echo "error: could not resolve substitutions commit" >&2; exit 1; }

# --- 5. report ---------------------------------------------------------------

ladder=$(printf '%s\n' "$candidates" | tr '\n' ' ' | sed 's/ $//')

say ""
if [ "$chosen" = "$upstream_latest" ]; then
    say "  nginx        $chosen        (newest release; otel apk + tarball, both arches)"
elif [ "$chosen" != "$upstream_in_series" ]; then
    say "  nginx        $chosen        (otel apk + source tarball, both arches)"
    say "               capped by otel: nginx.org has $upstream_in_series in the" \
        "$chosen_series series, $upstream_latest overall"
else
    say "  nginx        $chosen        (newest in the $chosen_series series;" \
        "nginx.org is at $upstream_latest overall)"
fi
say "  alpine       $alpine_version"
say "  otel apk     $otel_apk"
say "  gpg key      $gpg_key"
say "  headers-more $headers_more"
say "  fancyindex   $fancyindex"
say "  subs filter  ${subs_commit:0:12}"
say ""
say "  fallback ladder: $ladder"
say ""

cat <<EOF
NGINX_VERSION=$chosen
ALPINE_VERSION=$alpine_version
MODULE_URL_BASE=$REPO/v$alpine_version/main/
OTEL_APK=$otel_apk
GPG_KEYS=$gpg_key
MORE_SET_HEADER_VERSION=$headers_more
FANCYINDEX=$fancyindex
SUBS_FILTER_COMMIT=$subs_commit
NGINX_CANDIDATES="$ladder"
UPSTREAM_LATEST=$upstream_latest
UPSTREAM_IN_SERIES=$upstream_in_series
EOF
