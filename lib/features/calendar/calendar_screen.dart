import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import '../tasks/task_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final TasksApi _tasksApi = const TasksApi();

  bool isLoading = true;
  String? errorMessage;
  DateTime selectedMonth = DateTime.now();
  DateTime selectedDay = DateTime.now();
  List<TaskListItem> tasks = [];

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month);
    selectedDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    loadTasks();
  }

  Future<void> loadTasks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await _tasksApi.getTasks();

      if (!mounted) {
        return;
      }

      setState(() {
        tasks = data.tasks;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Calendar task load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Could not load calendar tasks.';
      });
    }
  }

  List<TaskListItem> tasksForDay(DateTime day) {
    return tasks.where((item) {
      final dueDate = item.task.dueDate;

      if (dueDate == null) {
        return false;
      }

      return _sameDay(dueDate, day);
    }).toList()..sort(compareUpcomingTaskItems);
  }

  List<TaskListItem> get overdueTasks {
    return tasks.where((item) => item.task.isOverdue).toList()
      ..sort(compareUpcomingTaskItems);
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextSecondary
        : PlanoraTheme.textSecondary;
  }

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
      );
      selectedDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
    });
  }

  void openTask(TaskListItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TaskDetailScreen(initialTask: item, onTaskChanged: loadTasks),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return _buildState(
        context,
        icon: Icons.wifi_off_rounded,
        title: errorMessage!,
        action: 'Try Again',
        onAction: loadTasks,
      );
    }

    return RefreshIndicator(
      onRefresh: loadTasks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _buildMonthHeader(context),
          const SizedBox(height: 14),
          _buildCalendarGrid(context),
          const SizedBox(height: 16),
          _buildSelectedDayTasks(context),
          const SizedBox(height: 16),
          _buildOverdueTasks(context),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _monthLabel(selectedMonth),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: () => changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: () => changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final leadingEmptySlots = firstDay.weekday % 7;
    final dayCount = DateUtils.getDaysInMonth(
      selectedMonth.year,
      selectedMonth.month,
    );
    final cells = List<DateTime?>.generate(leadingEmptySlots + dayCount, (
      index,
    ) {
      if (index < leadingEmptySlots) {
        return null;
      }

      return DateTime(
        selectedMonth.year,
        selectedMonth.month,
        index - leadingEmptySlots + 1,
      );
    });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          Row(
            children: const [
              _WeekdayLabel('Sun'),
              _WeekdayLabel('Mon'),
              _WeekdayLabel('Tue'),
              _WeekdayLabel('Wed'),
              _WeekdayLabel('Thu'),
              _WeekdayLabel('Fri'),
              _WeekdayLabel('Sat'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final day = cells[index];

              if (day == null) {
                return const SizedBox.shrink();
              }

              return _buildDayCell(context, day);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime day) {
    final dayTasks = tasksForDay(day);
    final isSelected = _sameDay(day, selectedDay);
    final isToday = _sameDay(day, DateTime.now());
    final color = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        setState(() {
          selectedDay = day;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : isToday
              ? color.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            if (dayTasks.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final task in dayTasks.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : _priorityColor(task.task.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayTasks(BuildContext context) {
    final dayTasks = tasksForDay(selectedDay);

    return _buildTaskSection(
      context,
      title: 'Tasks on ${formatShortDate(selectedDay)}',
      empty: 'No tasks due on this day.',
      items: dayTasks,
    );
  }

  Widget _buildOverdueTasks(BuildContext context) {
    return _buildTaskSection(
      context,
      title: 'Overdue Tasks',
      empty: 'No overdue tasks.',
      items: overdueTasks,
    );
  }

  Widget _buildTaskSection(
    BuildContext context, {
    required String title,
    required String empty,
    required List<TaskListItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              empty,
              style: TextStyle(
                color: mutedColor(context),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final item in items.take(8)) _buildTaskRow(context, item),
        ],
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, TaskListItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => openTask(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 38,
                decoration: BoxDecoration(
                  color: _priorityColor(item.task.priority),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildState(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? action,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(action)),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? PlanoraTheme.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return PlanoraTheme.success;
      case TaskPriority.medium:
        return PlanoraTheme.warning;
      case TaskPriority.high:
        return PlanoraTheme.error;
    }
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkTextSecondary
              : PlanoraTheme.textSecondary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
