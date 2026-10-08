#!/usr/bin/env bash
# Writes <dist>/version.json, the manifest the in-app updater reads from
# releases/latest/download/version.json instead of the GitHub API.
#
# usage: tool/release_manifest.sh <dist-dir> <tag> <repository> <notes-file>
set -euo pipefail

if (($# != 4)); then
  echo "usage: $0 <dist-dir> <tag> <repository> <notes-file>" >&2
  exit 2
fi

dist="$1"
tag="$2"
repository="$3"
notes="$4"
base="https://github.com/$repository/releases/download/$tag"

assets() {
  find "$dist" -maxdepth 1 -type f ! -name version.json -printf '%f\n' |
    LC_ALL=C sort |
    while IFS= read -r name; do
      file="$dist/$name"
      jq -n \
        --arg name "$name" \
        --arg url "$base/$name" \
        --argjson size "$(stat -c %s "$file")" \
        --arg sha256 "$(sha256sum -- "$file" | cut -d' ' -f1)" \
        '{name: $name, url: $url, size: $size, sha256: $sha256}'
    done
}

assets | jq -s \
  --arg tag "$tag" \
  --arg version "${tag#v}" \
  --rawfile notes "$notes" \
  '{tag: $tag, version: $version, notes: $notes, assets: .}' \
  >"$dist/version.json"
