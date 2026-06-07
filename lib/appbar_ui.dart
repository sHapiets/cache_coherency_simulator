import 'dart:ui';

import 'package:cache_coherency_simulator/main.dart';
import 'package:flutter/material.dart';

class AppbarUI extends StatelessWidget implements PreferredSizeWidget {
  const AppbarUI({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 0,

      flexibleSpace: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x22000000), width: 1.2),
          ),
        ),
      ),

      titleSpacing: 24,

      title: Row(
        children: [
          // CHIP ICON
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  color: Color(0x222E6F80),
                ),
              ],
            ),

            child: Icon(
              Icons.move_down_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.surface,
            ),
          ),

          const SizedBox(width: 14),

          // TITLE SECTION
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Cache Coherency Simulator",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  fontFamily: "Nunito",
                ),
              ),

              Text(
                "Multi-processor Cache Protocols for Coherency",
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).disabledColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                  fontFamily: "Roboto-Mono",
                ),
              ),
            ],
          ),
        ],
      ),

      actions: [
        /* 
        _toolbarButton(Icons.play_arrow_rounded, "Run"),

        _toolbarButton(Icons.skip_next_rounded, "Step"),

        _toolbarButton(Icons.restart_alt_rounded, "Reset"), */
        _toolbarButton(
          Icons.light_mode_rounded,
          Theme.of(context).colorScheme.primary,
          "Light Mode",
          () {
            themeModeNotifier.value = ThemeMode.light;
          },
        ),

        _toolbarButton(
          Icons.dark_mode_rounded,
          Theme.of(context).colorScheme.tertiary,
          "Dark Mode",
          () {
            themeModeNotifier.value = ThemeMode.dark;
          },
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _toolbarButton(
    IconData icon,
    Color color,
    String tooltip,
    Function() onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x14000000)),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
