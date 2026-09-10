#!/bin/bash
# Capture one open-source project under WSL into an idir on /mnt/c, so that
# a Windows cov-analyze can analyze it and the PATHOUT count can be read.
#
#   usage (from WSL): campaign.sh <name> <git url> <ref> <build recipe>
#   recipes: autoconf | cmake | make
#
# Writes: /mnt/c/Data/pathout-campaign/idirs/<name>   (the idir)
#         /mnt/c/Data/pathout-campaign/logs/<name>.*  (configure/build logs)
set -uo pipefail
NAME="${1:?name}"; URL="${2:?url}"; REF="${3:?ref}"; RECIPE="${4:?autoconf|cmake|make}"
COV="${COV:-/mnt/c/Coverity/cov-analysis-linux64-2026.6.0/bin}"
WS=/mnt/c/Data/pathout-campaign
SRC="$HOME/campaign/$NAME"
IDIR="$WS/idirs/$NAME"
CFG="$WS/cfg"
mkdir -p "$WS/logs" "$CFG" "$HOME/campaign"

if [ ! -e "$CFG/coverity_config.xml" ]; then
  "$COV/cov-configure" --config "$CFG/coverity_config.xml" --template --compiler gcc --comptype gcc > "$WS/logs/cov-configure.log" 2>&1
  "$COV/cov-configure" --config "$CFG/coverity_config.xml" --template --compiler g++ --comptype g++ >> "$WS/logs/cov-configure.log" 2>&1
  "$COV/cov-configure" --config "$CFG/coverity_config.xml" --template --compiler cc --comptype gcc >> "$WS/logs/cov-configure.log" 2>&1
fi

if [ ! -d "$SRC/.git" ]; then
  git clone -q --depth 1 --branch "$REF" "$URL" "$SRC" || { echo "[$NAME] clone failed"; exit 1; }
fi
cd "$SRC"
rm -rf "$IDIR"; mkdir -p "$IDIR"
case "$RECIPE" in
  autoconf)
    [ -x ./configure ] || autoreconf -fi > "$WS/logs/$NAME.autoreconf.log" 2>&1
    ./configure > "$WS/logs/$NAME.configure.log" 2>&1 || { echo "[$NAME] configure failed"; exit 1; }
    BUILD="make -j8"
    ;;
  cmake)
    mkdir -p build && (cd build && cmake .. -DCMAKE_BUILD_TYPE=Debug > "$WS/logs/$NAME.configure.log" 2>&1) || { echo "[$NAME] cmake failed"; exit 1; }
    BUILD="make -C build -j8"
    ;;
  make)
    BUILD="make -j8"
    ;;
esac
"$COV/cov-build" --config "$CFG/coverity_config.xml" --dir "$IDIR" $BUILD > "$WS/logs/$NAME.build.log" 2>&1
echo "[$NAME] $(grep -o 'Emitted [0-9]* C/C++ compilation units ([0-9]*%)' "$WS/logs/$NAME.build.log" | tail -1)  build exit noted in $WS/logs/$NAME.build.log"
