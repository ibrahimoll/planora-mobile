import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import 'data/deadline_reminders_api.dart';
import 'models/deadline_reminder_model.dart';

class DeadlineRemindersScreen extends StatefulWidget {
  final DeadlineRemindersApi remindersApi;

  const DeadlineRemindersScreen({
    super.key,
    this.remindersApi = const DeadlineRemindersApi(),
  });

  @override
  State<DeadlineRemindersScreen> createState() =>
      _DeadlineRemindersScreenState();
}

class _DeadlineRemindersScreenState extends State<DeadlineRemindersScreen> {
  late final DeadlineRemindersApi _remindersApi;

  bool isLoading = true;
  bool isRunningCheck = false;
  String? errorMessage;
  List<DeadlineReminderModel> reminders = [];

  @override
  void initState() {
    super.initState();
    _remindersApi = widget.remindersApi;
    loadReminders();
  }

  Future<void> loadReminders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedReminders = await _remindersApi.getMyDeadlineReminders();

      if (!mounted) return;

      setState(() {
        reminders = loadedReminders;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Deadline reminders load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not load deadline reminders.';
        isLoading = false;
      });
    }
  }

  Future<void> runReminderCheck() async {
    setState(() {
      isRunningCheck = true;
      errorMessage = null;
    });

    try {
      await _remindersApi.runDeadlineReminders();
      await loadReminders();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deadline reminder check completed.')),
      );
    } catch (error, stackTrace) {
      debugPrint('Deadline reminder check failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not run deadline reminder check.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not run reminder check.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isRunningCheck = false;
        });
      }
    }
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration cardDecoration(BuildContext context, {double radius = 22}) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }

  DateTime todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? dateOnly(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  bool isOverdue(DeadlineReminderModel reminder) {
    final due = dateOnly(reminder.dueDate);
    if (due == null) return false;
    return due.isBefore(todayOnly());
  }

  bool isDueSoon(DeadlineReminderModel reminder) {
    final due = dateOnly(reminder.dueDate);
    if (due == null || isOverdue(reminder)) return false;

    final days = due.difference(todayOnly()).inDays;
    return days <= 3;
  }

  List<DeadlineReminderModel> overdueReminders() {
    return reminders.where(isOverdue).toList();
  }

  List<DeadlineReminderModel> dueSoonReminders() {
    return reminders.where(isDueSoon).toList();
  }

  List<DeadlineReminderModel> laterReminders() {
    return reminders
        .where((reminder) => !isOverdue(reminder) && !isDueSoon(reminder))
        .toList();
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'No due date';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String relativeDueLabel(DateTime? date) {
    final due = dateOnly(date);
    if (due == null) return 'No due date';

    final diff = due.difference(todayOnly()).inDays;

    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff == -1) return '1 day overdue';
    if (diff < 0) return '${diff.abs()} days overdue';
    return 'Due in $diff days';
  }

  Color reminderAccentColor(DeadlineReminderModel reminder) {
    if (isOverdue(reminder)) return PlanoraTheme.error;
    if (isDueSoon(reminder)) return PlanoraTheme.warning;
    if (reminder.isSent) return PlanoraTheme.success;
    return PlanoraTheme.secondaryPurple;
  }

  String reminderStatusLabel(DeadlineReminderModel reminder) {
    if (isOverdue(reminder)) return 'Overdue';
    if (isDueSoon(reminder)) return 'Due soon';
    if (reminder.isSent) return 'Sent';
    return 'Pending';
  }

  Widget buildHeader(BuildContext context) {
    final totalCount = reminders.length;
    final overdueCount = overdueReminders().length;

    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: cardDecoration(context, radius: 999),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deadline Reminders',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  totalCount == 0
                      ? 'No reminders yet'
                      : overdueCount > 0
                      ? '$overdueCount overdue · $totalCount total'
                      : '$totalCount reminders',
                  key: ValueKey<String>('$totalCount-$overdueCount'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : loadReminders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isRunningCheck ? null : runReminderCheck,
            icon: isRunningCheck
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(isRunningCheck ? 'Checking' : 'Run check'),
          ),
        ),
      ],
    );
  }

  Widget buildContent(BuildContext context) {
    if (isLoading) {
      return buildStateCard(
        context,
        icon: Icons.sync_rounded,
        title: 'Loading deadline reminders...',
        showSpinner: true,
      );
    }

    if (errorMessage != null) {
      return buildStateCard(
        context,
        icon: Icons.wifi_off_rounded,
        title: errorMessage!,
        buttonText: 'Try Again',
        onPressed: loadReminders,
      );
    }

    if (reminders.isEmpty) {
      return buildStateCard(
        context,
        icon: Icons.event_available_rounded,
        title: 'No deadline reminders yet',
        message:
            'When tasks approach their due dates, reminders will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildReminderSection(
          context,
          title: 'Overdue',
          items: overdueReminders(),
          emptyMessage: 'No overdue reminders.',
        ),
        buildReminderSection(
          context,
          title: 'Due Soon',
          items: dueSoonReminders(),
          emptyMessage: 'Nothing due soon.',
        ),
        buildReminderSection(
          context,
          title: 'Later',
          items: laterReminders(),
          emptyMessage: 'No later reminders.',
        ),
      ],
    );
  }

  Widget buildReminderSection(
    BuildContext context, {
    required String title,
    required List<DeadlineReminderModel> items,
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < items.length; index++) ...[
            buildReminderCard(context, items[index]),
            if (index != items.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget buildReminderCard(
    BuildContext context,
    DeadlineReminderModel reminder,
  ) {
    final isDark = PlanoraTheme.isDark(context);
    final accent = reminderAccentColor(reminder);
    final title = reminder.taskTitle ?? reminder.title;
    final projectTitle = reminder.projectTitle ?? 'No project name';
    final message = reminder.message;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(context, radius: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent, accent.withValues(alpha: 0.45)],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: accent.withValues(alpha: 0.14)),
            ),
            child: Icon(Icons.event_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? PlanoraTheme.darkTextPrimary
                              : PlanoraTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    buildStatusPill(context, reminder),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  projectTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor(context),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    buildMetaPill(context, relativeDueLabel(reminder.dueDate)),
                    buildMetaPill(context, formatDate(reminder.dueDate)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusPill(BuildContext context, DeadlineReminderModel reminder) {
    final accent = reminderAccentColor(reminder);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        reminderStatusLabel(reminder),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildMetaPill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? message,
    String? buttonText,
    VoidCallback? onPressed,
    bool showSpinner = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(context),
      child: Column(
        children: [
          if (showSpinner)
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            )
          else
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: RefreshIndicator(
                onRefresh: loadReminders,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    buildHeader(context),
                    const SizedBox(height: 20),
                    buildActionRow(context),
                    const SizedBox(height: 18),
                    buildContent(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
