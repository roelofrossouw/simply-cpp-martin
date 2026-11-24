# simply-cpp-martin

[Martin](https://maplibre.org/martin/) (MapLibre's tile server: vector tiles from PostGIS,
MBTiles and PMTiles, fonts as glyph PBFs, SVG folders as sprites), its official Linux x86_64
build packaged as an apt package. There's no source of ours here beyond the packaging: the binary
is the release Martin publishes, downloaded and checked against `SHA256.txt`.

This exists so a server or container gets Martin with `apt install` from apt.roelof.co.za,
updated like any other package, instead of a binary copied by hand.

## Install

```bash
curl -fsSL https://apt.roelof.co.za/setup.sh | bash
sudo apt -y install simply-cpp-martin
martin --version
```

It installs `/usr/bin/martin` and Martin's licences, nothing else: no configuration, no service.
Run it under your own unit with your own configuration (`martin --config /etc/martin/config.yaml`).
The build is glibc-linked (libcurl, libuv, libstdc++), so the package has those as Depends. It is
published for resolute only (`SC_DISTS="noble resolute" scripts/deploy.sh` on demand).

## The version

`VERSION.txt` is the Martin release packaged (its tag is `martin-v<version>`), `SHA256.txt` the
SHA-256 of that release's `martin-x86_64-unknown-linux-gnu.tar.gz`, as GitHub lists it for the asset
(`gh release view martin-v<version> -R maplibre/martin --json assets`).

## Publishing a new version

Set `VERSION.txt` and `SHA256.txt`, check the binary's libraries (`readelf -d martin | grep NEEDED`)
against the Depends in `scripts/publish.sh`, commit, then:

```bash
scripts/deploy.sh
```

The suite's `scripts/publish.sh --only martin` does the same for it. The same version packaged
again (a packaging change) takes a `REVISION.txt`: 1.16.1-1.

## Licence

The packaging scripts are Apache-2.0 (`LICENSE`); Martin itself is MIT or Apache-2.0, its licences
shipped in the package (`/usr/share/doc/simply-cpp-martin/copyright`).
