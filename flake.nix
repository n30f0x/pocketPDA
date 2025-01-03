{
  description = "Prototype";

  nixConfig = {
    extra-experimental-features = [ "nix-command" "flakes" ];
    allow = [ "nonfree" ];
  };

  inputs = {
    nixpkgs = {
      url = "flake:nixpkgs/nixpkgs-unstable";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, agenix, ... }@inputs:
   let

      linuxSystems  = [ "x86_64-linux" "aarch64-linux" ];
      darwinSystems = [ "x86_64-darwin" "aarch64-darwin" ];
      exoticSystems = [ "i686-linux" "armv7l-linux" "armv5tel-linux" "aarch64-apple-darwin" ];
      allSystems = linuxSystems ++ darwinSystems;
      allSystemsInsane = linuxSystems ++ darwinSystems ++ exoticSystems;

      forSystem = systemsIN: f: nixpkgs.lib.genAttrs systemsIN
       (system: f {
          pkgs = import nixpkgs { inherit overlays system; };
      });
      forSystemGen = systemsIN: nixpkgs.lib.genAttrs systemsIN;

      recursiveMerge = with nixpkgs.lib; attrList:
        let f = attrPath:
          zipAttrsWith (n: values:
            if tail values == []
              then head values
            else if all isList values
              then unique (concatLists values)
            else if all isAttrs values
              then f (attrPath ++ [n]) values
            else last values
          );
        in f [] attrList;

      patchedPkgs =
        let
          patches = [
            # Place your nixpkgs patches here
          ];
          patched = systemsIN: import "${nixpkgs.legacyPackages.${systemsIN}.applyPatches {
              inherit patches;
              name = "nixpkgs-patched";
              src = nixpkgs;
          }}/flake.nix";
          invoked = patched.outputs { self = invoked; };
        in
        if builtins.length patches > 0 then invoked else nixpkgs;

      inherit (patchedPkgs) lib;

      overlays = [
        (self: super: {
        })
      ];


   in {


      devShells = forSystem (linuxSystems ++ darwinSystems) (
      { pkgs }:
      let
        availableShells = import ./devShells/core.nix { inherit pkgs recursiveMerge agenix; };
      in
         {
          # core
           inherit (availableShells) core develop;
         } // {
           default = with availableShells; core;
         }
      );

      templates = {
        generic = {
          path = ".";
          description = "Generic template";
          welcomeText = ''
            # Getting started
            - Ensure you have git installed and flakes enabled
            - Run `nix develop`
            '';
        };

    };
  };
}
