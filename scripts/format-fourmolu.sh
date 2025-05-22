set -e

echo "The custom options for formatting this repo are:"
fourmolu --version
fourmolu --print-defaults | diff - ./fourmolu.yaml | grep -E "^>.*[[:alnum:]]" | grep -v "#"
printf "\nFormatting haskell files...\n"

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

case "$(uname -s)" in
    MINGW*)     path="$(pwd -W | sed 's_/_\\\\_g')\\\\(rawlock|strict-checked-vars|resource-registry)";;
    *)          path="$(pwd)/(rawlock|strict-checked-vars|resource-registry)";;
esac

$fdcmd --full-path "$path" \
       --extension hs \
       --exec-batch fourmolu --config fourmolu.yaml -i

case "$(uname -s)" in
    MINGW*) git ls-files --eol | grep "w/crlf" | awk '{print $4}' | xargs dos2unix;;
    *) ;;
esac || true
