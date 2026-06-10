import 'package:flutter/material.dart';

class TeamsScreen extends StatelessWidget {
  final Object? teamsApi;
  final Object? projectsApi;
  final Object? tasksApi;
  final bool showBackButton;
  final VoidCallback? onTeamsChanged;
  const TeamsScreen({super.key, this.teamsApi, this.projectsApi, this.tasksApi, this.showBackButton = false, this.onTeamsChanged});
  @override
  Widget build(BuildContext context) {
    return const