{
  description = "A Nix Flake for Flutter Development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };

        # For nix install via flake input.
        flutter-app = pkgs.flutter.buildFlutterApplication {
          pname = "chatfusion";
          version = "1.0.0";
          src = ./app;
          flutterBuildFlags = [ "--release" ];
          pubspecLock = nixpkgs.lib.importJSON ./app/pubspec.lock.json;

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
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
          ];

          meta = with pkgs.lib; {
            description = "ChatFusion - Chat with LLMs";
            homepage = "https://github.com/Force67/chatfusion";
            license = licenses.gpl3;
            platforms = platforms.linux;
          };

        };

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          toolsVersion = "26.1.1";
          platformToolsVersion = "34.0.4";
          buildToolsVersions = [ "34.0.0" ];
          platformVersions = [
            "34"
            "35"
          ];
          includeEmulator = false;
          includeSources = true;
          includeSystemImages = false;
          includeNDK = false;
          ndkVersion = "25.1.8937393";
          useGoogleAPIs = false;
          extraLicenses = [
            "android-sdk-license"
            "android-sdk-preview-license"
            "google-gdk-license"
          ];
        };

        runtimeLibs = pkgs.lib.makeLibraryPath (
          with pkgs;
          [
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
          ]
        );

        clangEnv = pkgs.buildEnv {
          name = "clang-env";
          paths = with pkgs; [
            clang
            lld
            libcxx
            libunwind
          ];
        };

      in
      {
        packages.default = flutter-app;

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
            patchelf
            androidComposition.androidsdk
            chromium
            rsync
          ];

          buildInputs = with pkgs; [
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
            # Set up writable Android SDK
            export ANDROID_SDK_ROOT="$PWD/android-sdk"
            mkdir -p "$ANDROID_SDK_ROOT"
            rsync -a --chmod=+w ${androidComposition.androidsdk}/libexec/android-sdk/ "$ANDROID_SDK_ROOT/"

            # Fix command line tools directory structure
            mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/latest"
            ln -sfn "$ANDROID_SDK_ROOT/cmdline-tools/bin" "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin" || true

            # Environment variables
            export ANDROID_HOME="$ANDROID_SDK_ROOT"
            export CHROME_EXECUTABLE="${pkgs.chromium}/bin/chromium"
            export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

            # Compiler configuration
            export CC="${clangEnv}/bin/clang"
            export CXX="${clangEnv}/bin/clang++"
            export LD="${pkgs.binutils}/bin/ld"
            export AR="${pkgs.binutils}/bin/ar"

            # Library paths
            export LD_LIBRARY_PATH="${runtimeLibs}:$LD_LIBRARY_PATH"
            export LIBRARY_PATH="${runtimeLibs}:$LIBRARY_PATH"

            # Linker flags
            export LDFLAGS="-fuse-ld=lld \
              -Wl,-rpath,${runtimeLibs} \
              -L${pkgs.zlib}/lib \
              -L${pkgs.glibc}/lib \
              -Wl,--dynamic-linker=${pkgs.glibc}/lib/ld-linux-x86-64.so.2"

            # Initial setup
            flutter clean >/dev/null 2>&1
            echo "Writable Android SDK available at: $ANDROID_SDK_ROOT"
            echo "Run 'flutter doctor --android-licenses' to accept remaining licenses"
            echo "Development environment ready!"
          '';
        };
      }
    );
}
