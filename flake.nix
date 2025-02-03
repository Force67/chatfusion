{
  description = "A Nix Flake for Flutter Development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:  # Added 'self' parameter here
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            flutter

            androidsdk
            android-tools
            android-studio


            gradle
            jdk11
            cmake
            dart
            glib
            glib.dev
            google-chrome
            gtk3
            gtk3.dev
            lcov
            ninja
            nvfetcher
            pkg-config
            sqlite
            sqlite-web
            nodePackages.firebase-tools
            sd
            fd

            # Linux-specific dependencies
            xorg.libX11
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXi
            libGL
            pcre2
            libsysprof-capture  # Add this line
            util-linux

            # Add GCC and related tools
            gcc
            gcc-unwrapped
            binutils
            gnumake

            protobuf
            protoc-gen-dart
          ];

          shellHook = ''
            # Set up paths for GCC and standard C library headers
            export C_INCLUDE_PATH="${pkgs.gcc-unwrapped}/lib/gcc/${pkgs.stdenv.hostPlatform.config}/${pkgs.gcc-unwrapped.version}/include:${pkgs.glibc.dev}/include:${pkgs.glib.dev}/include/glib-2.0:${pkgs.glib.out}/lib/glib-2.0/include:$C_INCLUDE_PATH"
            export CPLUS_INCLUDE_PATH="$C_INCLUDE_PATH:${pkgs.gcc-unwrapped}/include/c++/${pkgs.gcc-unwrapped.version}:${pkgs.gcc-unwrapped}/include/c++/${pkgs.gcc-unwrapped.version}/${pkgs.stdenv.hostPlatform.config}:$CPLUS_INCLUDE_PATH"

            # Set paths for glibc and gcc
            export GLIBC_LIB=${pkgs.glibc}/lib
            export GCC_LIB=${pkgs.gcc-unwrapped}/lib/gcc/${pkgs.stdenv.hostPlatform.config}/${pkgs.gcc-unwrapped.version}

            # Set compiler and linker flags
            export CFLAGS="-B$GLIBC_LIB -B$GCC_LIB -I${pkgs.glibc.dev}/include $CFLAGS"
            export CXXFLAGS="$CFLAGS"
            export LDFLAGS="-B$GLIBC_LIB -B$GCC_LIB -L${pkgs.gcc-unwrapped.lib}/lib -L${pkgs.glibc}/lib $LDFLAGS"
            export NIX_LDFLAGS="-L$GLIBC_LIB -L$GCC_LIB -L${pkgs.gcc-unwrapped.lib}/lib -L${pkgs.glibc}/lib -rpath ${pkgs.gcc-unwrapped.lib}/lib -rpath ${pkgs.glibc}/lib $NIX_LDFLAGS"

            # Set CMake compiler and library paths
            export CMAKE_C_COMPILER=${pkgs.gcc}/bin/gcc
            export CMAKE_CXX_COMPILER=${pkgs.gcc}/bin/g++
            export LD_LIBRARY_PATH="${pkgs.gcc-unwrapped.lib}/lib:${pkgs.glibc}/lib:${pkgs.pcre2}/lib:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="${pkgs.pcre2}/lib/pkgconfig:${pkgs.glib.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"

            # Configure Flutter settings
            mkdir -p $HOME/.flutter_settings
            echo '{"enable-linux-desktop":true,"linux-desktop-cc":"${pkgs.gcc}/bin/gcc","linux-desktop-cxx":"${pkgs.gcc}/bin/g++"}' > $HOME/.flutter_settings/settings.json
          '';
        };
      });
}
