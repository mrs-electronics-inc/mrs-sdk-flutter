{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    devshell.url = "github:numtide/devshell";
    android-nixpkgs.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = inputs@{ nixpkgs, devshell, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          devshell.overlays.default
          (final: _prev: {
            android-sdk = inputs.android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
              build-tools-35-0-0
              cmdline-tools-latest
              platform-tools
              platforms-android-35
              platforms-android-36
              ndk-28-2-13676358
              cmake-3-22-1
            ]);
          })
        ];
      };
    in
    {
      devShell.${system} = import ./devshell.nix { inherit pkgs; };
    };
}
