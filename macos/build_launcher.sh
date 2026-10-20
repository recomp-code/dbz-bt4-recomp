#!/bin/bash
# build_launcher.sh <out> [server]: the Recomp launcher (Go + Wails: recomp-code/recomp-online, launcher/) for macOS,
# with the online server built in. RECOMP_ONLINE = that repository's checkout.
set -euo pipefail
SRC="${RECOMP_ONLINE:-$HOME/NBAStreetRecomp/recomp-online}/launcher"
SERVER="${2:-https://nbas3.xellrecomp.party}"
OUT="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
cd "$SRC"
CGO_LDFLAGS="-framework UniformTypeIdentifiers" MACOSX_DEPLOYMENT_TARGET=14.0 GOTOOLCHAIN=local \
    go build -tags desktop,production -trimpath -ldflags "-s -w -X main.defaultServer=$SERVER" -o "$OUT" . 2>&1 |
    { grep -v -e 'deprecated' -e 'note:' -e 'WailsContext' -e '^ ' -e 'duplicate libraries' -e '^#' || true; }
test -x "$OUT"
