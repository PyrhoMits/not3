#!/usr/bin/env fish

# Install the hand-sized Android launcher resources exactly as supplied. Using
# flutter_launcher_icons here would resize the adaptive foreground again.

set -l script_path (realpath (status filename))
set -l repo_root (realpath (dirname "$script_path")/..)
set -l source_root "$repo_root/docs/assets/android"
set -l resource_root "$repo_root/android/app/src/main/res"

for density in ldpi mdpi hdpi xhdpi xxhdpi xxxhdpi
    set -l source_dir "$source_root/mipmap-$density"
    set -l target_dir "$resource_root/mipmap-$density"

    if not test -d "$source_dir"
        echo "Missing launcher icon directory: $source_dir" >&2
        exit 1
    end

    mkdir -p "$target_dir"
    cp "$source_dir/ic_launcher.png" "$target_dir/ic_launcher.png"
    cp "$source_dir/ic_launcher_round.png" "$target_dir/ic_launcher_round.png"

    if test -f "$source_dir/ic_launcher_foreground.png"
        cp "$source_dir/ic_launcher_foreground.png" "$target_dir/ic_launcher_foreground.png"
    end
end

mkdir -p "$resource_root/mipmap-anydpi-v26"
cp "$source_root/mipmap-anydpi-v26/ic_launcher.xml" \
    "$resource_root/mipmap-anydpi-v26/ic_launcher.xml"
cp "$source_root/mipmap-anydpi-v26/ic_launcher_round.xml" \
    "$resource_root/mipmap-anydpi-v26/ic_launcher_round.xml"

# Keep the existing target filename so this color has exactly one definition.
cp "$source_root/values/ic_launcher_background.xml" \
    "$resource_root/values/colors.xml"

echo 'Installed the pre-sized Android launcher icons.'
