{
  description = "A Nix Flake for Flutter Development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };

        # Create runtime library path
        runtimeLibs = pkgs.lib.makeLibraryPath (with pkgs; [
          zlib
          glib
          gtk3
          pango
          cairo
          gdk-pixbuf
          atk
          harfbuzz
          libepoxy
          libGL
          xorg.libX11
          sqlite
          glibc
        ]);

        # Create a complete Clang environment
        clangEnv = pkgs.buildEnv {
          name = "clang-env";
          paths = with pkgs; [
            clang
            lld
            #compiler-rt
            libcxx
            #libcxxabi
            libunwind
          ];
        };

      in
      {
        devShell = pkgs.mkShell {
          NIX_ENFORCE_PURITY = 1;

          nativeBuildInputs = with pkgs; [
            flutter
            cmake
            ninja
            pkg-config
            lcov
            jdk17
            clangEnv
            binutils
            patchelf  # Add patchelf for fixing binary paths
          ];

          buildInputs = with pkgs; [
            # Android toolchain
            androidsdk
            android-tools
            android-studio

            # Linux dependencies
            gtk3
            glib
            gdk-pixbuf
            pango
            cairo
            atk
            harfbuzz
            libepoxy
            sqlite
            xorg.libX11
            libGL
            zlib
            glibc.static
            gcc-unwrapped
          ];

          shellHook = ''
            # Full isolation from host system
            unset XDG_DATA_DIRS
            export PATH="${clangEnv}/bin:${pkgs.binutils}/bin:$PATH"

            # Explicit compiler configuration
            export CC="${clangEnv}/bin/clang"
            export CXX="${clangEnv}/bin/clang++"
            export AR="${pkgs.binutils}/bin/ar"
            export LD="${pkgs.binutils}/bin/ld"

            # Library paths
            export LD_LIBRARY_PATH="${runtimeLibs}:$LD_LIBRARY_PATH"
            export LIBRARY_PATH="${runtimeLibs}:$LIBRARY_PATH"
            export C_INCLUDE_PATH="${pkgs.glibc.dev}/include"
            export CPLUS_INCLUDE_PATH="${pkgs.glibc.dev}/include"

            # Linker configuration with rpath
            export LDFLAGS="-fuse-ld=lld \
              -Wl,-rpath,${runtimeLibs} \
              -L${pkgs.zlib}/lib \
              -L${pkgs.glibc}/lib \
              -L${pkgs.gcc-unwrapped}/lib \
              -Wl,--dynamic-linker=${pkgs.glibc}/lib/ld-linux-x86-64.so.2"

            # CMake configuration
            export CMAKE_PREFIX_PATH="${pkgs.zlib};${pkgs.glibc}"

            # Function to fix runtime paths after build
            fix_binary_paths() {
              echo "Fixing runtime paths for executable..."
              patchelf --set-rpath "${runtimeLibs}" build/linux/x64/debug/bundle/monkeychat
            }

            # Clean build artifacts
            flutter clean >/dev/null 2>&1

            # Add post-build hook
            export FLUTTER_POST_BUILD_HOOK="fix_binary_paths"

            echo "Development environment ready!"
            echo "Runtime libraries available at: ${runtimeLibs}"
          '';
        };
      }
    );
}
