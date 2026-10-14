#!/bin/bash
# Build dist/<id>-<version>.plasmoid (a zip with metadata.json at its root),
# the format the KDE Store and "Install from file" expect.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
pkg=$root/package

id=$(jq -r .KPlugin.Id "$pkg/metadata.json")
version=$(jq -r .KPlugin.Version "$pkg/metadata.json")
out=$root/dist/$id-$version.plasmoid

mkdir -p "$root/dist"
rm -f "$out"
(cd "$pkg" && zip -q -r -X "$out" metadata.json contents)
echo "$out"
