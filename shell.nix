let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {};
in
with pkgs;
pkgs.mkShell {
  buildInputs = [
    ansible
    awscli2
    jq
    python39Full
    python39Packages.boto3
    python39Packages.jinja2
    python39Packages.pyyaml
    terraform
  ];
}

