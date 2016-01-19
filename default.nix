# nix-build -E 'with import <nixpkgs> { }; callPackage ./default.nix { }'
{ stdenv, pkgs, coreutils, curl, icedtea8_web, openjdk8, patchelf, xmlstarlet }:

assert stdenv.system == "x86_64-linux";

let

  run = pkgs.writeScript "laucnh-ikvm" ''
    #!/usr/bin/env bash

    if [ -z "$1" ]; then
      echo 'No .jnlp file supplied'
      exit 1
    elif [ ! -f "$1" ]; then
      echo 'Invalid .jnlp'
      exit 1
    fi

    XPATH_JAR_RESOURCES='/jnlp/resources[@os="Linux" and (@arch="amd64" or @arch="x86_64")]'
    XPATH_JAR_RESOURCES_DELETE='/jnlp/resources[@os="Linux"]'

    JAR_FILE=$(${xmlstarlet}/bin/xml sel -t -v "$XPATH_JAR_RESOURCES[1]/nativelib/@href" "$1")

    CURL_BASE=$(${xmlstarlet}/bin/xml sel -t -v '/jnlp/@codebase' "$1")

    TMPDIR=$(${coreutils}/bin/mktemp -d)

    cd "$TMPDIR" || exit 1

    ${curl}/bin/curl "$CURL_BASE$JAR_FILE.pack.gz" --output "$JAR_FILE.pack.gz"
    ${openjdk8}/bin/unpack200 "$JAR_FILE.pack.gz" "$JAR_FILE"
    ${openjdk8}/bin/jar xf "$JAR_FILE"


    for i in libiKVM64.so libSharedLibrary64.so
    do
      ${patchelf}/bin/patchelf --set-rpath ${stdenv.cc.cc}/lib $i
    done

    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:`pwd`
    ${xmlstarlet}/bin/xml ed -d "$XPATH_JAR_RESOURCES_DELETE" "$1" > new-launch.jnlp
    ${icedtea8_web}/bin/javaws new-launch.jnlp

    rm -rf "$TMPDIR"
  '';

in

stdenv.mkDerivation rec {

  name = "launch-ikvm-0.1.0";

  src = ./.;

  installPhase = ''
    mkdir -p $out/bin
    ln -s ${run} $out/bin/launch-ikvm
  '';

}
