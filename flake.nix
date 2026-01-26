{
  description = "dst-data-cleaner";

  nixConfig.bash-prompt = "\[dev\]$ ";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-25.05;
  };

  outputs = { self, nixpkgs }: let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f rec {
      inherit system;

      pkgs = import nixpkgs { inherit system; };

      version = pkgs.lib.removeSuffix "\n" (builtins.readFile ./VERSION);
    });
  in rec {
    packages = forEachSupportedSystem ({ system, pkgs, version }: rec {
      locales = pkgs.glibcLocales.override {
        allLocales = false;
        locales    = ["en_US.UTF-8/UTF-8"];
      };

      pythonWithPackages = pkgs.python3.withPackages (ps: with ps; [
        behave
        jinja2
        psycopg2
        pytest
        faker
      ]);

      rWithPackages = pkgs.rWrapper.override{
        packages = with pkgs.rPackages; [
          tidyverse dtplyr data_table rlang haven readr plyr arrow rjson
        ];
      };

      default = pkgs.callPackage ./default.nix {
        inherit version;
        inherit locales;
        inherit pythonWithPackages;
        inherit rWithPackages;

        inherit (pkgs);
      };
    });

    devShells = forEachSupportedSystem ({ system, pkgs, version }: rec {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # Development releated packages
          openssl
          datamash
          nushell
          pkg-config
          packages."${system}".pythonWithPackages
          packages."${system}".rWithPackages
          nushell
        ];
      };
    });
  };
}
