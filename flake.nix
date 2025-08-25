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
      # packages = forEachSystem(pkgs: {
      # default = pkgs.callPackage ./. {};
      # });
      devShells = forEachSystem (
        pkgs: system: {
          default =
            let
              zig_version = "0.14.0-dev.2577+271452d22";
              my_zig = pkgs.zig.overrideAttrs (finalAttrs: {
                version = zig_version;
                src = pkgs.fetchzip {
                  url = "https://pkg.machengine.org/zig/zig-linux-x86_64-${zig_version}.tar.xz";
				  hash = "sha256-dgkWDmyfDd2ERyS9284Ei3RiLP+MRcpXxR3STDThmHk=";
                };
                nativeBuildInputs = [ ];
                buildInputs = [ ];
				dontConfigure = true;
				dontBuild = true;
				doInstallCheck = false;
				sourceRoot = ".";
				installPhase = ''
					runHook preInstall
					install -m755 -D $src/zig $out/bin/zig
					# install -m755 -D $src/lib $out/lib/
					cp -r $src/lib $out/bin/lib
					runHook postInstall
				'';
				postPatch = "";
				postInstall = ''
					install -Dm444 $src/doc/langref.html -t $doc/share/doc/zig-${finalAttrs.version}/html
				'';
              });
            in

            pkgs.mkShell {
              nativeBuildInputs = with pkgs; [
                my_zig
                pkg-config
                # wlroots_0_19
                wayland-scanner
                wayland-protocols
                wlr-protocols
              ];
              buildInputs = with pkgs; [
                wayland
                wayland-scanner
                wlroots_0_19
                wayland-protocols
                wlr-protocols
                pixman
                libxkbcommon

                vulkan-headers
                vulkan-loader
                libGL
              ];
              env.LD_LIBRARY_PATH = with pkgs; pkgs.lib.makeLibraryPath [ vulkan-loader wayland libxkbcommon ];
            };
        }
      );
    };
}
