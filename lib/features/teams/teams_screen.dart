import 'package:flutter/material.dart';
import '../auth/data/project_api.dart';
import '../tasks/data/tasks_api.dart';
import 'data/teams_api.dart';

class TeamsScreen extends StatefulWidget {
  final TeamsApi teamsApi;
  final ProjectsApi projectsApi;
  final TasksApi tasksApi;
  final bool showBackButton;
  final VoidCallback? onTeamsChanged;

  const TeamsScreen({
    super.key,
    this.teamsApi = const TeamsApi(),
    this.projects