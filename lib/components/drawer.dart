import "package:flutter/material.dart";
import "package:luffy/components/theme_selector.dart";
import "package:luffy/main.dart";
import "package:luffy/screens/login.dart";
import "package:luffy/screens/settings.dart";

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final malToken = MyApp.of(context)!.malToken;

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Row(
              children: [
                Text(
                  "Luffy ${MyApp.of(context)!.malToken != null ? "(logged in)" : ""}",
                ),
              ],
            ),
          ),
          if (malToken == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text("Login"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text("Theme"),
            onTap: () {
              showThemeDialog(
                context,
                onThemeChange: (c) {
                  MyApp.of(context)!.changeThemeColor(c);
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
