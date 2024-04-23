import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.ltr,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          "assets/images/mal.svg",
          colorFilter: const ColorFilter.mode(
            Color.fromARGB(255, 46, 81, 162),
            BlendMode.srcIn,
          ),
          width: 36,
          height: 36,
        ),
        const SizedBox(width: 8),
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            "Luffy",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.lightBlue,
              fontFamily: "MavenPro",
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
