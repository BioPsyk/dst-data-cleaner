FROM docker.io/nixos/nix:latest AS builder

WORKDIR /app

COPY flake.nix .
COPY flake.lock .
COPY default.nix .
COPY VERSION .

RUN nix \
    --extra-experimental-features "nix-command flakes" \
    --option filter-syscalls false \
    build ".#default"

RUN ./result/bin/dst-data-container-setup

ENTRYPOINT ["/app/entrypoint.sh"]
