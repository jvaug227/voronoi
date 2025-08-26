{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs =
    inputs@{ self, nixpkgs }:
    let
      forEachSystem =
        function:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system: function nixpkgs.legacyPackages.${system} system
        );
    in
    {
      devShells = forEachSystem (
        pkgs: system: {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              zig
            ];
            buildInputs = with pkgs; [
            ];
          };
        }
      );
    };
}
