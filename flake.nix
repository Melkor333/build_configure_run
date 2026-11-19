{
  description = "Dev shell for the build-configure-run diagram experiment (Ysh + PlantUML)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f nixpkgs.legacyPackages.${system}
        );
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            oils-for-unix
            plantuml
          ];

          shellHook = ''
            if command -v ysh >/dev/null && command -v plantuml >/dev/null; then
              echo "ysh $(ysh --version 2>/dev/null | head -1) and plantuml ready"
              echo "Build the site with: ysh ./pages.ysh"
            else
              echo "warning: ysh or plantuml missing from environment" >&2
            fi
          '';
        };
      });
    };
}
