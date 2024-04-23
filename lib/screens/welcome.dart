import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:luffy/components/logo.dart";
import "package:luffy/screens/home.dart";
import "package:luffy/screens/login.dart";
import "package:url_launcher/url_launcher.dart";

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ),
    );

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            flex: !isPortrait ? 17 : 15,
            child: Stack(
              children: [
                Transform.translate(
                  offset: Offset(
                    0,
                    isPortrait ? 100 : 0,
                  ),
                  child: Transform.scale(
                    scale: isPortrait ? 1.2 : 1,
                    child: Image.asset(
                      isPortrait
                          ? "assets/images/welcome_portrait.webp"
                          : "assets/images/welcome_landscape.webp",
                      width: MediaQuery.of(context).size.width,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Black overlay over the bottom half of the image.
                Positioned.fill(
                  top: MediaQuery.of(context).size.height / 2,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          offset: isPortrait
                              ? const Offset(
                                  0,
                                  128,
                                )
                              : const Offset(0, 0),
                          blurRadius: 128,
                          spreadRadius: 64,
                          color: Colors.black.withOpacity(isPortrait ? 0.9 : 1),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isPortrait)
                  Positioned.fill(
                    top: MediaQuery.of(context).size.height / 1.9,
                    child: const Column(
                      children: [
                        Expanded(child: Logo()),
                        SizedBox(height: 16),
                        Text(
                          "All your favorite anime. All in one place.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: !isPortrait ? 9 : 4,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                // border: Border.all(color: Colors.red),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: !isPortrait ? 32 : 0,
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      child: Column(
                        children: [
                          if (isPortrait) ...[
                            const Flexible(child: Logo()),
                            const SizedBox(height: 16),
                            const Text(
                              "All your favorite anime. All in one place.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Button which says Register,
                          Flexible(
                            child: TextButton(
                              onPressed: () {
                                launchUrl(
                                  Uri.parse(
                                    "https://myanimelist.net/register.php",
                                  ),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.onSurface,
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                fixedSize: const Size(350, 50),
                                shape: const RoundedRectangleBorder(),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    "assets/images/mal.svg",
                                    colorFilter: const ColorFilter.mode(
                                      Color.fromARGB(255, 34, 39, 43),
                                      BlendMode.srcIn,
                                    ),
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "CREATE ACCOUNT",
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 34, 39, 43),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Button which says Login
                          Flexible(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                fixedSize: const Size(350, 50),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    width: 2.0,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              child: const Text(
                                "LOG IN",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // hyperlink that says continue without an account (is clickable).
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "or",
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                  ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Continue without an account",
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isPortrait ? 56 : 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
