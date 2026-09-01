#!/usr/bin/env bash

set -euo pipefail

gap_version=4.16.1
core_sha256=b4433a540a2f746d14b1645a0e95b3d499afb180aa421ebfd62b427f2b0cf74f
packages_sha256=fb9350f66ec4febf09858f5475abe31dd91a97e827477e1da9eb393d07f311a8
release_url="https://github.com/gap-system/gap/releases/download/v${gap_version}"
core_name="gap-${gap_version}-core.tar.gz"
packages_name="packages-required-v${gap_version}.tar.gz"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

download() {
    local name=$1 expected=$2
    local path="$source_dir/$name"
    if [[ ! -f $path ]]; then
        curl --fail --location --retry 3 "$release_url/$name" -o "$path.part"
        mv "$path.part" "$path"
    fi
    [[ $(sha256 "$path") == "$expected" ]] || fail "Bad checksum: $name"
}

case "$(uname -s)/$(uname -m)" in
    Darwin/arm64) system_id=MacOSX-ARM64 ;;
    Darwin/x86_64) system_id=MacOSX-x86-64 ;;
    Linux/x86_64) system_id=Linux-x86-64 ;;
    *) fail "This system is not supported" ;;
esac

for tool in awk cc curl grep make tar; do require "$tool"; done
if [[ $system_id == Linux-* ]]; then
    require patchelf
else
    require install_name_tool
    require otool
    export MACOSX_DEPLOYMENT_TARGET=13.0
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_dir/.." && pwd)
source_dir="$repository_root/build/runtime-sources"
output_dir="$repository_root/build/runtimes/$system_id"
[[ ! -e $output_dir ]] || fail "Run make clean before rebuilding $system_id"
mkdir -p "$source_dir" "$output_dir"

download "$core_name" "$core_sha256"
download "$packages_name" "$packages_sha256"

work_dir=$(mktemp -d "$repository_root/build/runtime-work.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
tar -xzf "$source_dir/$core_name" -C "$work_dir"
gap_root="$work_dir/gap-$gap_version"
[[ -d $gap_root ]] || fail "GAP source was not extracted"

jobs=2
if command -v nproc >/dev/null 2>&1; then
    jobs=$(nproc)
elif command -v sysctl >/dev/null 2>&1; then
    jobs=$(sysctl -n hw.ncpu)
fi

printf 'Building GAP %s for %s...\n' "$gap_version" "$system_id"
if ! (
    cd "$gap_root"
    env -u CPATH -u CPPFLAGS -u LDFLAGS -u LIBRARY_PATH \
        ./configure --with-gmp=builtin --without-readline &&
        env -u CPATH -u CPPFLAGS -u LDFLAGS -u LIBRARY_PATH \
            make -j "$jobs"
) > "$output_dir/build.log" 2>&1; then
    tail -80 "$output_dir/build.log" >&2
    fail "GAP build failed"
fi

runtime="$output_dir/runtime"
mkdir -p "$runtime/licenses/gap" "$runtime/licenses/gmp" "$runtime/pkg" "$runtime/syslib"
install -m 755 "$gap_root/gap" "$runtime/gap"
cp -R "$gap_root/lib" "$gap_root/grp" "$runtime/"
tar -xzf "$source_dir/$packages_name" -C "$runtime/pkg"
cp "$gap_root/LICENSE" "$gap_root/COPYRIGHT" "$runtime/licenses/gap/"
cp "$gap_root"/extern/gmp/COPYING* "$runtime/licenses/gmp/"

if [[ $system_id == Linux-* ]]; then
    gmp_files=("$gap_root"/extern/install/gmp/lib/libgmp.so.[0-9]*)
    gmp=${gmp_files[0]}
    [[ -e $gmp ]] || fail "Built GMP library was not found"
    gmp_name=$(basename "$gmp")
    cp -L "$gmp" "$runtime/syslib/$gmp_name"
    needed=$(patchelf --print-needed "$runtime/gap" | awk '/libgmp/ && !found {value=$0; found=1} END {print value}')
    [[ -n $needed ]] || fail "GAP does not link to GMP"
    patchelf --replace-needed "$needed" "$gmp_name" "$runtime/gap"
    patchelf --set-rpath '$ORIGIN/syslib' "$runtime/gap"
    if {
        patchelf --print-needed "$runtime/gap"
        patchelf --print-rpath "$runtime/gap"
    } | grep -F "$work_dir" >/dev/null; then
        fail "Runtime links to its build directory"
    fi
else
    gmp_files=("$gap_root"/extern/install/gmp/lib/libgmp.*.dylib)
    gmp=${gmp_files[0]}
    [[ -e $gmp ]] || fail "Built GMP library was not found"
    gmp_name=$(basename "$gmp")
    cp "$gmp" "$runtime/syslib/$gmp_name"
    needed=$(otool -L "$runtime/gap" | awk '/libgmp/ && !found {value=$1; found=1} END {print value}')
    [[ -n $needed ]] || fail "GAP does not link to GMP"
    install_name_tool -change "$needed" "@loader_path/syslib/$gmp_name" "$runtime/gap"
    install_name_tool -id "@loader_path/$gmp_name" "$runtime/syslib/$gmp_name"
    if otool -L "$runtime/gap" "$runtime/syslib/$gmp_name" |
        grep -F "$work_dir" >/dev/null; then
        fail "Runtime links to its build directory"
    fi
fi

for package in gapdoc perfgrp primgrp smallgrp transgrp; do
    [[ -d $runtime/pkg/$package ]] || fail "Required package is missing: $package"
done

printf '%s\n' \
    "GAP $gap_version" \
    "System: $system_id" \
    "Core: $release_url/$core_name" \
    "Core SHA-256: $core_sha256" \
    "Required packages: $release_url/$packages_name" \
    "Required packages SHA-256: $packages_sha256" \
    > "$runtime/RUNTIME.txt"
printf '%s\n' \
    "GAP and its required packages are not part of GAPLink's MIT license." \
    "GAP and GMP license files are in this directory." \
    "Package license files are under ../pkg/." \
    "The release includes the matching source archives." \
    > "$runtime/licenses/README.txt"

(
    cd "$runtime"
    find . -type f -perm -111 -print | LC_ALL=C sort | sed 's|^\./||'
) > "$runtime/EXECUTABLES.txt"
grep -qx gap "$runtime/EXECUTABLES.txt" || fail "GAP is not executable"

version=$(
    "$runtime/gap" -q -n -A -r --nointeract \
        -c 'Print(GAPInfo.Version,"\n");QUIT_GAP(0);'
)
[[ $version == "$gap_version" ]] || fail "Built GAP returned version $version"
"$runtime/gap" -q -n -A -r --nointeract \
    -c 'if LoadPackage("gapdoc")=fail then Error("gapdoc failed");fi;QUIT_GAP(0);'

archive="$output_dir/GAPLink-runtime-$system_id.tar.gz"
tar -czf "$archive" -C "$output_dir" runtime
printf '%s  %s\n' "$(sha256 "$archive")" "$(basename "$archive")" \
    > "$archive.sha256"
printf 'OK: %s | GAP %s\n' "$runtime" "$version"
