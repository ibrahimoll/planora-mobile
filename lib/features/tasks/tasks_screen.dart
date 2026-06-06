import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import 'data/tasks_api.dart';
import 'models/task_models.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  final VoidCallback onBack;
  final int createRequestId;
  final VoidCallback? onTasksChanged;

  const TasksScreen({
    super.key,
    required this.onBack,
    this.createRequestId = 0,
    this.onTasksChanged,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TasksApi _tasksApi = const TasksApi();

  final TextEditingController titleController = TextEditingController();
  final