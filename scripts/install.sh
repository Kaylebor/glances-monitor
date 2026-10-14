#!/bin/bash
# Install or upgrade the widget for the current user from this checkout.
# Plasma loads widget code at startup: run `plasmashell --replace & disown`
# afterwards for a widget already on a panel to pick up changes.
set -euo pipefail
pkg=$(cd "$(dirname "$0")/../package" && pwd)
id=$(jq -r .KPlugin.Id "$pkg/metadata.json")

if kpackagetool6 --type Plasma/Applet --show "$id" >/dev/null 2>&1; then
	kpackagetool6 --type Plasma/Applet --upgrade "$pkg"
else
	kpackagetool6 --type Plasma/Applet --install "$pkg"
fi
