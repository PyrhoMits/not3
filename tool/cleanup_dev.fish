#!/usr/bin/env fish

# Remove Not3's Docker development container and host-side caches.
# Repository build output and Docker images are opt-in to avoid deleting an APK
# or resources shared with another project.

function show_help
    echo 'Usage: tool/cleanup_dev.fish [options]'
    echo
    echo 'Default cleanup:'
    echo '  - Stop and remove the elated_carver container.'
    echo '  - Remove ~/.cache/not3-docker-* directories.'
    echo '  - Remove ~/.cache/not3-flutter-sdk-* directories.'
    echo
    echo 'Options:'
    echo '  -c, --container   Container name or ID (default: elated_carver).'
    echo '  -r, --repo-build   Remove generated repository build files.'
    echo '                     Existing APKs are copied to dist/ first.'
    echo '  -i, --image        Also remove the local not3-flutter image.'
    echo '  -b, --base-image   Also remove ghcr.io/cirruslabs/flutter:stable.'
    echo '                     This image may be shared with other projects.'
    echo '  -n, --dry-run      Print actions without changing anything.'
    echo '  -y, --yes          Skip the confirmation prompt.'
    echo '  -h, --help         Show this help.'
end

argparse \
    'h/help' \
    'c/container=' \
    'r/repo-build' \
    'i/image' \
    'b/base-image' \
    'n/dry-run' \
    'y/yes' \
    -- $argv
or begin
    show_help >&2
    exit 2
end

if set -q _flag_help
    show_help
    exit 0
end

if test (count $argv) -ne 0
    echo 'Unexpected argument:' $argv[1] >&2
    show_help >&2
    exit 2
end

if not set -q HOME; or test -z "$HOME"
    echo 'HOME is not set; refusing to resolve cache paths.' >&2
    exit 1
end

set -l script_path (realpath (status filename))
set -l repo_root (realpath (dirname "$script_path")/..)
set -l cache_base (realpath -m "$HOME/.cache")
set -l container_name elated_carver
if set -q _flag_container
    set container_name $_flag_container
end
set -g cleanup_dry_run 0
if set -q _flag_dry_run
    set cleanup_dry_run 1
end

set -l cache_targets
if test -d "$cache_base"
    set cache_targets (find "$cache_base" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        \( -name 'not3-docker-*' -o -name 'not3-flutter-sdk-*' \) \
        -print \
        | sort)
end

# Never pass an unexpected path to recursive removal.
for target in $cache_targets
    if not string match -q -- "$cache_base/not3-docker-*" "$target"; and \
            not string match -q -- "$cache_base/not3-flutter-sdk-*" "$target"
        echo "Unsafe cache target: $target" >&2
        exit 1
    end
end

set -l repo_targets
if set -q _flag_repo_build
    set repo_targets \
        "$repo_root/.dart_tool" \
        "$repo_root/.flutter-plugins" \
        "$repo_root/.flutter-plugins-dependencies" \
        "$repo_root/build" \
        "$repo_root/android/.gradle" \
        "$repo_root/linux/flutter/ephemeral"
end

echo 'Not3 development cleanup'
echo "  Repository: $repo_root"
echo "  Container:  $container_name"

if test (count $cache_targets) -gt 0
    echo '  Host caches:'
    for target in $cache_targets
        set -l size_line (du -sh "$target" 2>/dev/null)
        set -l size (string replace -r '\s.*$' '' -- "$size_line")
        if test -z "$size"
            set size unknown
        end
        echo "    $size  $target"
    end
else
    echo '  Host caches: none found'
end

if set -q _flag_repo_build
    echo '  Repository build output: remove (APKs copied to dist/)'
else
    echo '  Repository build output: keep'
end

if set -q _flag_image
    echo '  Docker image not3-flutter: remove'
end
if set -q _flag_base_image
    echo '  Shared Flutter base image: remove'
end
if set -q _flag_dry_run
    echo '  Mode: dry run'
end

if not set -q _flag_yes; and not set -q _flag_dry_run
    read --local --prompt-str='Continue? [y/N] ' answer
    switch (string lower -- "$answer")
        case y yes
        case '*'
            echo 'Cancelled.'
            exit 0
    end
end

function run_command
    echo '+ ' (string join ' ' -- (string escape -- $argv))
    if test $cleanup_dry_run -eq 0
        command $argv
    end
end

if command -q docker
    if docker container inspect "$container_name" >/dev/null 2>&1
        set -l is_running (docker container inspect \
            --format '{{.State.Running}}' "$container_name")
        set -l auto_remove (docker container inspect \
            --format '{{.HostConfig.AutoRemove}}' "$container_name")

        if test "$is_running" = true
            run_command docker container stop "$container_name"
        end

        # A container started with --rm disappears after stop.
        if test "$auto_remove" != true
            run_command docker container rm "$container_name"
        end
    else
        echo "Container $container_name does not exist."
    end
else
    echo 'Docker is unavailable; skipping container and image cleanup.' >&2
end

for target in $cache_targets
    if test -e "$target"
        run_command rm -rf -- "$target"
    end
end

if set -q _flag_repo_build
    set -l apk_output "$repo_root/dist"
    set -l apks
    if test -d "$repo_root/build"
        set apks (find "$repo_root/build" -type f -name '*.apk' -print)
    end

    if test (count $apks) -gt 0
        run_command mkdir -p "$apk_output"
        for apk in $apks
            run_command cp -f -- "$apk" "$apk_output/"(basename "$apk")
        end
    end

    for target in $repo_targets
        if not string match -q -- "$repo_root/*" "$target"
            echo "Unsafe repository target: $target" >&2
            exit 1
        end
        if test -e "$target"
            run_command rm -rf -- "$target"
        end
    end
end

if command -q docker
    if set -q _flag_image
        if docker image inspect not3-flutter >/dev/null 2>&1
            run_command docker image rm not3-flutter
        end
    end

    if set -q _flag_base_image
        if docker image inspect ghcr.io/cirruslabs/flutter:stable >/dev/null 2>&1
            run_command docker image rm ghcr.io/cirruslabs/flutter:stable
        end
    end
end

echo 'Cleanup complete.'
