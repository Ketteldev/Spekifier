#!/bin/sh
# Package src/ for installation; requires Linux coreutils and Info-ZIP zip/unzip.
set -eu

if [ "$#" -gt 1 ]; then
    printf 'Usage: sh %s [output.zip]\n' "$0" >&2
    exit 2
fi
for tool in zip unzip; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf "Missing %s command; install your distribution's zip and unzip packages.\n" "$tool" >&2
        exit 1
    fi
done
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
source_dir=$(realpath -- "$script_dir/../src")
output=$(realpath -m -- "${1:-$script_dir/../dist/Spekifier.zip}")
case "$output" in
    "$source_dir"|"$source_dir"/*)
        printf 'Package output must be outside src/.\n' >&2
        exit 1 ;;
esac
if [ ! -f "$source_dir/Spekifier.toc" ]; then
    printf 'src/Spekifier.toc is missing.\n' >&2
    exit 1
fi
if [ -d "$output" ]; then
    printf 'Package output must be a file.\n' >&2
    exit 1
fi
mkdir -p -- "$(dirname -- "$output")"
staging=$(mktemp -d "$(dirname -- "$output")/.spekifier.XXXXXX")
trap 'rm -rf -- "$staging"' 0
trap 'exit 1' HUP INT TERM
mkdir -- "$staging/Spekifier"
cp -R -- "$source_dir/." "$staging/Spekifier/"
(
    cd -- "$staging"
    unset ZIPOPT
    zip -q -r -D release.zip Spekifier
    zip -q -T release.zip
)
mv -f -- "$staging/release.zip" "$output"
printf 'Created %s\n' "$output"
