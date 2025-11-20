{ stdenv, lib, version, openssl, pkg-config, coreutils, writeShellApplication, glibc, locales, tzdata, shadow, netcat, pythonWithPackages, rWithPackages, nextflow }:

writeShellApplication rec {
  name = "dst-data-container-setup";

  runtimeInputs = [
    coreutils
    glibc.bin
    locales
    netcat
    openssl
    pkg-config
    pythonWithPackages
    rWithPackages
    shadow
    stdenv.shell
    tzdata
  ];

  text = ''
    TMP_DIR="/tmp/pcs-docker-setup"

    rm -rf "''${TMP_DIR}"
    mkdir -p "''${TMP_DIR}"

    cp /etc/group "''${TMP_DIR}/group"
    cp /etc/shadow "''${TMP_DIR}/shadow"
    cp /etc/passwd "''${TMP_DIR}/passwd"

    unlink /etc/group
    unlink /etc/shadow
    unlink /etc/passwd

    mv "''${TMP_DIR}/group" /etc/group
    mv "''${TMP_DIR}/shadow" /etc/shadow
    mv "''${TMP_DIR}/passwd" /etc/passwd

    mkdir -p /etc/pam.d
    if [[ ! -f /etc/pam.d/other ]]; then
      cat > /etc/pam.d/other <<EOF
    account sufficient pam_unix.so
    auth sufficient pam_rootok.so
    password requisite pam_unix.so nullok yescrypt
    session required pam_unix.so
    EOF
    fi
    if [[ ! -f /etc/login.defs ]]; then
      touch /etc/login.defs
    fi

    groupadd -g 1000 service
    useradd -u 1000 -g service -m service

    cat > /app/entrypoint.sh <<'EOF'
    #!${stdenv.shell}

    set -o errexit
    set -o nounset
    set -o pipefail

    export TZDIR="${tzdata}/share/zoneinfo"
    export TZ="Europe/Stockholm"
    export LOCALE_ARCHIVE="${locales}/lib/locale/locale-archive";
    export PATH="$PATH:${lib.makeBinPath runtimeInputs}"
    export LANG="en_US.UTF-8"

    exec "$@"
    EOF

    chmod +x /app/entrypoint.sh
  '';
}
