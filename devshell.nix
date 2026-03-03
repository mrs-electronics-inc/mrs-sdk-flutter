{ pkgs }:

pkgs.devshell.mkShell {
  name = "mrs-sdk-flutter";
  motd = ''
    Entered the MRS Flutter SDK development environment.
  '';

  env = [
    {
      name = "ANDROID_HOME";
      value = "${pkgs.android-sdk}/share/android-sdk";
    }
    {
      name = "ANDROID_SDK_ROOT";
      value = "${pkgs.android-sdk}/share/android-sdk";
    }
    {
      name = "JAVA_HOME";
      value = pkgs.jdk.home;
    }
    {
      name = "GRADLE_OPTS";
      value = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${pkgs.android-sdk}/share/android-sdk/build-tools/35.0.0/aapt2";
    }
  ];

  packages = with pkgs; [
    flutter
    android-sdk
    gradle
    jdk
    git
    just
  ];
}
