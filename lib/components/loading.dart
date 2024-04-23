import "package:flutter/material.dart";
import "package:luffy/components/logo.dart";

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Logo(),
          SizedBox(height: 16),
          CircularProgressIndicator(),
        ],
      ),
    );
  }
}
