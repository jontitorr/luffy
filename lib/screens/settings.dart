import "package:flutter/material.dart";
import "package:luffy/main.dart";

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final malToken = MyApp.of(context)!.malToken;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Account",
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (malToken != null) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(
                      "https://avatars.githubusercontent.com/u/59069386?v=4",
                    ),
                    radius: 36,
                  ),
                  SizedBox(width: 16),
                  Text(
                    "Username",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Preferences",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const ListTile(
                  title: Text(
                    "Appearance",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 14,
                  ),
                ),
                if (malToken != null)
                  ListTile(
                    title: const Text(
                      "Log Out",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      MyApp.of(context)!.setToken(null);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
