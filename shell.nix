{ pkgs ? import <nixpkgs> {} }:
let
  basePython = pkgs.python3;
  localPython = basePython.withPackages (p: with p; [
    boto3
    jinja2
    pyyaml
  ]);
in
pkgs.mkShell {
  buildInputs = [
    localPython
    pkgs.ansible
    pkgs.jq
    pkgs.terraform
  ];
}

