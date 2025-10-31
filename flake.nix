{
  description = "evilbit - Evil Bit Kernel Module (RFC 3514)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        kernel = pkgs.linuxPackages_latest;
      in
      {
        packages = {
          evilbit = pkgs.stdenv.mkDerivation {
            pname = "evilbit";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = with pkgs; [
              kernel.kernel.dev
              kmod
              gnumake
            ];

            hardeningDisable = [ "all" ];

            buildPhase = ''
              make -C ${kernel.kernel.dev}/lib/modules/${kernel.kernel.modDirVersion}/build \
                M=$(pwd) modules
            '';

            installPhase = ''
              mkdir -p $out/lib/modules/${kernel.kernel.modDirVersion}/extra
              cp evilbit.ko $out/lib/modules/${kernel.kernel.modDirVersion}/extra/
            '';

            meta = with pkgs.lib; {
              description = "Evil Bit kernel module - Sets RFC 3514 evil bit on all IPv4 packets";
              homepage = "https://github.com/burdzwastaken/evilbit";
              license = licenses.gpl2Only;
              platforms = platforms.linux;
            };
          };

          default = self.packages.${system}.evilbit;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # build essentials
            kernel.kernel.dev
            kmod
            gnumake

            # toolchain (matches kernel)
            rustc
            cargo
            rust-analyzer
            rustfmt
            clippy

            # testing
            tcpdump
            wireshark
            iproute2
            iputils
          ];

          shellHook = ''
            export KDIR="${kernel.kernel.dev}/lib/modules/${kernel.kernel.modDirVersion}/build"
            
            echo "evilbit dev environment"
            echo "======================="
            echo "Kernel: ${kernel.kernel.version}"
            echo "Rust:   $(rustc --version)"
            echo "KDIR:   $KDIR"
          '';
        };
      }
    );
}
