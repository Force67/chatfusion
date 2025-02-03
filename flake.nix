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
          config.allowUnfree = true;
        };

        gcc = pkgs.gcc;
        gcc-unwrapped = pkgs.gcc-unwrapped;
        glibc = pkgs.glibc;

        # Explicit paths to critical compiler components
        crt1Path = "${glibc}/lib/crt1.o";
        crtiPath = "${glibc}/lib/crti.o";
        crtnPath = "${glibc}/lib/crtn.o";
        crtbeginPath = "${gcc-unwrapped}/lib/gcc/${pkgs.targetPlatform.config}/${gcc-unwrapped.version}/crtbeginS.o";
        crtendPath = "${gcc-unwrapped}/lib/gcc/${pkgs.targetPlatform.config}/${gcc-unwrapped.version}/crtendS.o";

      in
      {
        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            flutter
            cmake
            ninja
            pkg-config
            gtk3
            gtk3.dev
            sqlite
            xorg.libX11
            libGL
            lcov
            jdk11
            gcc
            gcc-unwrapped
            binutils
          ];

          buildInputs = with pkgs; [
            glib
            glib.dev
            gtk3
            gdk-pixbuf
            pango
            atk
            harfbuzz
            libepoxy
          ];

          shellHook = ''
            # Total environment isolation
            export PATH="${gcc}/bin:${pkgs.binutils}/bin:$PATH"
            unset LD_LIBRARY_PATH

            # Explicit compiler configuration
            export CC="${gcc}/bin/gcc"
            export CXX="${gcc}/bin/g++"
            export LD="${gcc}/bin/ld"

            # Manual CRT file specification
            export CRTI="${crtiPath}"
            export CRTN="${crtnPath}"
            export CRT1="${crt1Path}"
            export CRTBEGIN="${crtbeginPath}"
            export CRTEND="${crtendPath}"

            # Critical path configurations
            export LIBRARY_PATH="${gcc-unwrapped}/lib:${gcc-unwrapped}/lib/gcc/${pkgs.targetPlatform.config}/${gcc-unwrapped.version}:${glibc}/lib"
            export C_INCLUDE_PATH="${glibc.dev}/include:${gcc-unwrapped}/include"
            export CPLUS_INCLUDE_PATH="${glibc.dev}/include:${gcc-unwrapped}/include/c++/${gcc-unwrapped.version}"

            # Hardcoded linker flags
            export LDFLAGS="\
              -B${gcc-unwrapped}/lib/gcc/${pkgs.targetPlatform.config}/${gcc-unwrapped.version} \
              -B${glibc}/lib \
              -L${gcc-unwrapped}/lib \
              -L${glibc}/lib \
              -Wl,${crt1Path} \
              -Wl,${crtiPath} \
              -Wl,${crtbeginPath} \
              -Wl,${crtendPath} \
              -Wl,${crtnPath} \
              -Wl,--dynamic-linker=${glibc}/lib/ld-linux-x86-64.so.2"

            # CMake configuration
            export CMAKE_PREFIX_PATH="${gcc}:${gcc-unwrapped}:${glibc}"


            echo "Isolated environment with GCC ${gcc.version}"
            echo "CRT files:"
            echo "  crtbegin: ${crtbeginPath}"
            echo "  crtend: ${crtendPath}"
          '';
        };
      }
    );
}
