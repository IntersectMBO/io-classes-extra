#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=C.UTF-8
# First, try to find the 'fd' command
fdcmd="fd"
if ! command -v "$fdcmd" &> /dev/null; then
    # In Ubuntu systems the fd command is called fdfind.
    # If 'fd' is not found, try 'fdfind'
    fdcmd="fdfind"
    if ! command -v "$fdcmd" &> /dev/null; then
        echo "Error: Neither 'fd' nor 'fdfind' command found." >&2
        exit 1
    fi
fi

$fdcmd -p . -e cabal -x cabal-fmt -i

case "$(uname -s)" in
    MINGW*) git ls-files --eol | grep "w/crlf" | awk '{print $4}' | xargs dos2unix;;
    *) ;;
esac
