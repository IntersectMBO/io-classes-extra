#!/usr/bin/env bash

set -euo pipefail

PARGS="-p ."
CARGS=""

while getopts p:cd flag
do
    case "${flag}" in
        p) PARGS="-p ${OPTARG}";;
        c) CARGS="-c ${OPTARG}";;
        d) CARGS="-c .stylish-haskell.yaml";;
    esac
done

echo "Running stylish-haskell script with arguments: $PARGS $CARGS"

export LC_ALL=C.UTF-8

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

$fdcmd $PARGS -e hs -E resource-registry/test/Main.hs -X stylish-haskell $CARGS -i

case "$(uname -s)" in
    MINGW*) git ls-files --eol | grep "w/crlf" | awk '{print $4}' | xargs dos2unix;;
    *) ;;
esac
