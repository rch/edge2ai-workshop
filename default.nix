{ nixpkgs ? import <nixpkgs> {  } }:
 
let
  pkgs = [
    nixpkgs.boto3
    nixpkgs.terraform
  ];
 
in
  nixpkgs.stdenv.mkDerivation {
    name = "env";
    buildInputs = pkgs;
  }
