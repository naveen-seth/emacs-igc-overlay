{
  description = "Overlay for Emacs builds from the feature/igc branch";

  inputs = {
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.0.1.tar.gz";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-igc-src = {
      url = "github:emacs-mirror/emacs/feature/igc";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      emacs-overlay,
      emacs-igc-src,
      ...
    }:
    {
      overlays.default = self.overlays.emacs-igc-overlay;
      overlays.emacs-igc-overlay =
        final: prev:
        prev.lib.composeManyExtensions [
          emacs-overlay.overlays.default
          (final': prev': {
            emacs-igc = prev'.callPackage (
              {
                withBuildDetails ? false,
                withMpsAs ? "yes",
                ...
              }@args:
              assert prev'.lib.assertOneOf "withMpsAs" withMpsAs [
                "yes"
                "no"
                "debug"
              ];
              let
                extraArgs = builtins.removeAttrs args [
                  "withBuildDetails"
                  "withMpsAs"
                ];
              in
              (prev'.emacs-git.override extraArgs).overrideAttrs (attrs: {
                name = "emacs-igc";
                src = emacs-igc-src;
                buildInputs = attrs.buildInputs ++ [ prev'.mps ];
                configureFlags =
                  with prev';
                  (lib.subtractLists [
                    (lib.enableFeature (!withBuildDetails) "build-details")
                  ] attrs.configureFlags)
                  ++ [
                    (lib.enableFeature withBuildDetails "build-details")
                    (lib.withFeatureAs true "mps" withMpsAs)
                  ];
              })
            ) { };
          })
        ] final prev;

      packages =
        let
          inherit (nixpkgs) lib;
          forAllSystems = lib.genAttrs lib.systems.flakeExposed;
        in
        forAllSystems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
            };
          in
          {
            default = self.packages.${system}.emacs-igc;
            emacs-igc = pkgs.emacs-igc;
            emacs-igc-pgtk = pkgs.emacs-igc.override {
              withPgtk = true;
            };
          }
        );
    };
}
