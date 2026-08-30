{
  description = "matplotlib: version-bumped ahead of nixpkgs through a Python package overlay.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-lib = {
      url = "github:jgus/flake-lib/v1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { nixpkgs, flake-utils, flake-lib, ... }:
    let
      pin = import ./pin.nix;
      inherit (pin) version hash;
      source = { type = "pypi"; pname = "matplotlib"; format = "sdist"; };
      overlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {
            matplotlib =
              if pyprev.matplotlib.version == version
              then pyprev.matplotlib
              else
                pyprev.matplotlib.overridePythonAttrs (oldAttrs: {
                  inherit version;
                  doCheck = false;
                  postPatch = (oldAttrs.postPatch or "") + final.lib.optionalString (final.lib.hasPrefix "3.10." version) ''
                    substituteInPlace pyproject.toml \
                      --replace-fail "meson-python>=0.13.1,<0.17.0" meson-python
                  '';
                  mesonFlags =
                    if final.lib.hasPrefix "3.10." version
                    then builtins.filter (flag: flag != "-Dsystem-libraqm=true") oldAttrs.mesonFlags
                    else oldAttrs.mesonFlags;
                  src = pyfinal.fetchPypi { inherit version hash; pname = "matplotlib"; };
                });
          })
        ];
      };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            matplotlib = pkgs.python3.pkgs.matplotlib;
            default = pkgs.python3.pkgs.matplotlib;
            update-version = flake-lib.lib.mkUpdateVersion { inherit pkgs source; buildAttr = "matplotlib"; };
            update-branches = flake-lib.lib.mkUpdateBranches { inherit pkgs source; pinSchema = "pypi"; };
          };
        }) // {
      overlays.default = overlay;
    };
}
