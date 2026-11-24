#!/bin/bash
#~~~~~~~~~~
# Downloads the pinned Martin release (MapLibre's tile server, its official Linux x86_64 glibc
# build), checks it against SHA256.txt, packages its martin binary as the simply-cpp-martin .deb
# and publishes it into the apt repo for resolute (SC_DISTS overrides). The .deb is the same
# whichever build server packs it (deploy.sh defaults to build-noble; the repo is shared).
#
# Run this in the directory deploy.sh synced it to (/var/www/build/sc-martin).

set -euo pipefail

version=$(tr -d ' \t\n' < VERSION.txt)
checksum=$(tr -d ' \t\n' < SHA256.txt)
tag="martin-v${version}"
tarball="martin-x86_64-unknown-linux-gnu.tar.gz"
url="https://github.com/maplibre/martin/releases/download/${tag}/${tarball}"
package="simply-cpp-martin"
# A packaging revision (REVISION.txt) when the same upstream version is packaged again:
# 1.16.1-1 sorts after 1.16.1.
revision=$( [ -f REVISION.txt ] && tr -d ' \t\n' < REVISION.txt || true)
package_version="${version}${revision:+-$revision}"
deb_file="${package}_${package_version}_amd64.deb"

mkdir -p work
local_tarball="work/${tag}-${tarball}"
if [ ! -f "$local_tarball" ]; then
    echo "Downloading $url"
    wget -q -O "$local_tarball.part" "$url"
    mv "$local_tarball.part" "$local_tarball"
fi
# The release as published, or nothing: SHA256.txt is the tarball's SHA-256 as GitHub lists it
# for the release asset, checked when VERSION.txt was set.
if ! echo "$checksum  $local_tarball" | sha256sum -c --quiet -; then
    echo "$tarball doesn't match SHA256.txt: not packaged" >&2
    rm -f "$local_tarball"
    exit 1
fi
for licence in LICENSE-MIT LICENSE-APACHE; do
    if [ ! -f "work/$licence-$version" ]; then
        wget -q -O "work/$licence-$version" "https://raw.githubusercontent.com/maplibre/martin/${tag}/$licence"
    fi
done

rm -rf pkg work/extracted
mkdir -p pkg/DEBIAN pkg/usr/bin work/extracted
tar xzf "$local_tarball" -C work/extracted
# martin only: the tarball's martin-cp and mbtiles tools aren't asked for.
install -m 755 work/extracted/martin pkg/usr/bin/martin

# Depends: the binary's own NEEDED libraries (readelf -d), as dpkg-shlibdeps gave them on resolute
# for 1.16.1. Check again for a new version: readelf -d work/extracted/martin | grep NEEDED.
cat > pkg/DEBIAN/control <<CONTROL
Package: $package
Version: $package_version
Architecture: amd64
Depends: libc6 (>= 2.39), libcurl4t64 (>= 7.16.3), libgcc-s1 (>= 4.2), libstdc++6 (>= 13), libuv1t64 (>= 1.4.2)
Section: web
Priority: optional
Maintainer: Roelof Rossouw
Homepage: https://maplibre.org/martin/
Description: Martin, MapLibre's vector tile server, packaged for apt
 Martin $version's official Linux x86_64 build, installed as /usr/bin/martin,
 so it can be installed like any other package instead of copied by hand. It
 serves vector tiles from PostGIS, MBTiles and PMTiles, fonts as glyph PBFs and
 SVG folders as sprites. It brings no configuration or service: run it with
 your own (martin --config /etc/martin/config.yaml).
CONTROL

install -d "pkg/usr/share/doc/$package"
{
    echo "$package packages Martin $version (https://github.com/maplibre/martin),"
    echo "licensed under either of MIT or Apache-2.0, at your option."
    echo "The packaging scripts (https://github.com/roelofrossouw/simply-cpp-martin) are Apache-2.0."
    echo
    echo "----- Martin: LICENSE-MIT -----"
    cat "work/LICENSE-MIT-$version"
    echo
    echo "----- Martin: LICENSE-APACHE -----"
    cat "work/LICENSE-APACHE-$version"
} > "pkg/usr/share/doc/$package/copyright"

# The binary runs: a broken download or a build for another machine stops here.
pkg/usr/bin/martin --version

dpkg-deb --build --root-owner-group pkg "$deb_file"

pushd /var/www/build/repo >/dev/null
export GNUPGHOME=/var/www/build/signing
# resolute only (renderd2 runs resolute); SC_DISTS="noble resolute" publishes elsewhere on demand.
for dist in ${SC_DISTS:-resolute}; do
    if reprepro list "$dist" | grep -q "$package .*$package_version"; then
        echo "$dist: $package $package_version already published"
    else
        echo "$dist: publishing $package $package_version"
        reprepro remove "$dist" "$package" || true
        reprepro includedeb "$dist" "/var/www/build/sc-martin/$deb_file"
    fi
done
popd >/dev/null

echo "Done."
