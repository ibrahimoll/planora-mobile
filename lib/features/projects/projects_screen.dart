import 'package:flutter/material.dart';

class ProjectsScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ProjectsScreen({super.key, required this.onBack});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Widget buildProjectsHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        InkWell(
          onTap: widget.onBack,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 26,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Projects',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
          ),
        ),
        const Spacer(),
        buildCircleIconButton(
          context,
          icon: Icons.search_rounded,
          onTap: () {},
        ),
        const SizedBox(width: 10),
        buildCircleIconButton(context, icon: Icons.tune_rounded, onTap: () {}),
      ],
    );
  }

  Widget buildCircleIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Color(0xFF1E293B)
              : const Color.fromARGB(255, 240, 238, 238),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(children: [buildProjectsHeader(context)]),
    );
  }
}
