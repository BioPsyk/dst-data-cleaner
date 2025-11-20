{ stdenv, fetchurl, unzip, dos2unix }:

stdenv.mkDerivation rec {
  # Danish registers: data management and analyses from PSEMAU (Aarhus University)
  # https://doi.org/10.17605/OSF.IO/ZHFYP
  pname   = "psemau-data-management";
  version = "1.0.0";

  src = fetchurl {
    pname = "psemau-data-management-src";
    url   = "https://files.de-1.osf.io/v1/resources/zhfyp/providers/osfstorage/?zip=";
    hash  = "sha256-t0s6eGahX+Vxha7mk4uRft5aRhGW9aHzB+wuCKsIitY=";

    inherit version;
  };

  # src = ./src.zip;

  phases = "installPhase";

  buildInputs = [
    unzip
    dos2unix
  ];

  installPhase = ''
    mkdir -p $out/src

    unzip $src -d .

    cd ./'Data management code'
    for curr_path in ./*.R; do
      new_path=$(echo "$curr_path" | sed -e 's/ /_/g' | sed -e 's/[()]//g')
      new_name=$(basename "$new_path")

      mv "$curr_path" "$new_path"

      dos2unix "$new_path"

      cp "$new_path" "$out/src/$new_name.R"
    done;
  '';
}
