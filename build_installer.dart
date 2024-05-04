import "dart:io";

import "package:innosetup/innosetup.dart";
// ignore: depend_on_referenced_packages
import "package:version/version.dart";

void main() {
  InnoSetup(
    app: InnoSetupApp(
      name: "luffy",
      version: Version.parse("0.1.0"),
      publisher: "author",
      urls: InnoSetupAppUrls(
        homeUrl: Uri.parse("https://xminent.com/"),
      ),
    ),
    files: InnoSetupFiles(
      executable: File("build/windows/x64/runner/Release/luffy.exe"),
      location: Directory("build/windows/x64/runner/Release"),
    ),
    name: const InnoSetupName("windows_installer"),
    location: InnoSetupInstallerDirectory(
      Directory("build/windows/x64/runner/Release"),
    ),
    icon: InnoSetupIcon(
      File("assets/images/logo.ico"),
    ),
  ).make();
}
