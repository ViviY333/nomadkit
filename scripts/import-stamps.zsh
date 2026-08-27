#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
source_dir="$repo_root/stamps/app"
asset_catalog="$repo_root/NomadKit/Resources/Assets.xcassets"

if [[ ! -d "$source_dir" || ! -d "$asset_catalog" ]]; then
    print -u2 "Stamp source or asset catalog is missing."
    exit 1
fi

typeset -A selected

# Prefer the default artwork. Use an -alt file only when it is the sole asset
# available for that country code.
for source_path in "$source_dir"/*.png; do
    filename=${source_path:t}
    [[ "$filename" == *-alt.png ]] && continue
    code=${filename%%-*}
    selected[${code:u}]=$source_path
done

for source_path in "$source_dir"/*-alt.png(N); do
    filename=${source_path:t}
    code=${filename%%-*}
    code=${code:u}
    [[ -n ${selected[$code]-} ]] || selected[$code]=$source_path
done

imported=0
for code in ${(ok)selected}; do
    code_lower=${code:l}
    image_set="$asset_catalog/Stamp${code}.imageset"
    destination_name="stamp-${code_lower}.png"
    mkdir -p "$image_set"
    cp "${selected[$code]}" "$image_set/$destination_name"
    printf '%s\n' \
        "{\"images\":[{\"filename\":\"$destination_name\",\"idiom\":\"universal\",\"scale\":\"1x\"}],\"info\":{\"author\":\"xcode\",\"version\":1}}" \
        > "$image_set/Contents.json"
    imported=$((imported + 1))
done

print "Imported $imported stamp assets from $source_dir"
