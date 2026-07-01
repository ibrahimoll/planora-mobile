import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../ai/data/ai_plan_api.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import '../tasks/task_detail_screen.dart';
import 'data/project_insights_api.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;
  final ProjectsApi projectsApi;
  final TasksApi tasksApi;
  final AiPlanApi aiPlanApi;
  final ProjectInsightsApi insightsApi;
  final VoidCallback? onProjectChanged;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    this.projectsApi = const ProjectsApi(),
    this.tasksApi = const TasksApi(),
    this.aiPlanApi = const AiPlanApi(),
    this.insightsApi = const ProjectInsightsApi(),
    this.onProjectChanged,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  static const double pageX = 8;

  late final ProjectsApi _projectsApi = widget.projectsApi;
  late final TasksApi _tasksApi = widget.tasksApi;
  late final ProjectInsightsApi _insightsApi = widget.insightsApi;
  late ProjectModel _project = widget.project;

  bool _loading = true;
  bool _savingRisk = false;
  bool _previewingSchedule = false;
  bool _applyingSchedule = false;
  bool _requestingReport = false;
  bool _openingReport = false;
  int? _deletingTaskId;
  int _taskFilterIndex = 0;
  String? _error;
  String? _scheduleMessage;
  String? _reportStatus;
  String? _reportReason;
  String? _reportDate;

  List<TaskListItem> _tasks = [];
  List<ProjectMemberModel> _members = [];
  List<ProjectActivityModel> _activity = [];
  List<Map<String, dynamic>> _riskHistory = [];
  List<AiPlanHistoryModel> _aiPlans = [];
  ProjectProgressModel? _progress;
  RiskAnalysisPreviewModel? _risk;
  SmartSchedulePreviewModel? _schedule;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _list(dynamic value) => value is List ? value : const <dynamic>[];

  String _text(Map<String, dynamic> map, String key, {String fallback = ''}) {
    final value = map[key];
    return value == null ? fallback : value.toString();
  }

  num _num(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  String _friendly(Object err, String fallback) {
    if (err is ApiException && err.message.trim().isNotEmpty) return err.message;
    return fallback;
  }

  void _snack(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<List<Map<String, dynamic>>> _loadRiskHistory(int projectId) async {
    final response = await ApiClient.get('/projects/$projectId/risk-analysis');
    return _list(response).map(_map).where((item) => item.isNotEmpty).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final project = await _projectsApi.getProject(_project);
      final tasks = await _tasksApi.getProjectTasks(project: TaskProjectSummary.fromProject(project));
      final members = await _projectsApi.getProjectMembers(project);

      ProjectProgressModel? progress;
      RiskAnalysisPreviewModel? risk;
      List<Map<String, dynamic>> riskHistory = const [];
      List<ProjectActivityModel> activity = const [];
      List<AiPlanHistoryModel> plans = const [];
      String? reportStatus;
      String? reportReason;
      String? reportDate;

      try {
        progress = await _insightsApi.getProjectProgress(project.projectId);
      } catch (_) {}
      try {
        risk = await _insightsApi.previewRisk(project.projectId);
      } catch (_) {}
      try {
        riskHistory = await _loadRiskHistory(project.projectId);
      } catch (_) {}
      try {
        activity = await _insightsApi.getProjectActivity(projectId: project.projectId, limit: 8);
      } catch (_) {}
      try {
        plans = await _insightsApi.getAiPlanHistory(project);
      } catch (_) {}

      try {
        final data = await ApiClient.get('/reports/requests/me', queryParameters: {'project_id': project.projectId});
        final items = _list(_map(data)['items']);
        if (items.isNotEmpty) {
          final latest = _map(items.first);
          reportStatus = _text(latest, 'status');
          reportReason = _text(latest, 'rejection_reason');
          reportDate = _text(latest, 'resolved_at');
        }
      } catch (_) {}

      try {
        final data = await ApiClient.get('/reports/projects/${project.projectId}/exports', queryParameters: {'limit': 1, 'offset': 0});
        final items = _list(_map(data)['items']);
        if (items.isNotEmpty && reportStatus != 'pending' && reportStatus != 'rejected') {
          reportStatus = 'ready';
          reportDate ??= _text(_map(items.first), 'created_at');
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _project = project;
        _tasks = tasks;
        _members = members;
        _progress = progress;
        _risk = risk;
        _riskHistory = riskHistory;
        _activity = activity;
        _aiPlans = plans;
        _reportStatus = reportStatus;
        _reportReason = reportReason;
        _reportDate = reportDate;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(err, 'Could not load project details.');
      });
    }
  }

  Future<void> _saveRiskAnalysis() async {
    if (_savingRisk) return;
    setState(() => _savingRisk = true);
    try {
      await ApiClient.postJson('/projects/${_project.projectId}/risk-analysis');
      final risk = await _insightsApi.previewRisk(_project.projectId);
      final history = await _loadRiskHistory(_project.projectId);
      if (!mounted) return;
      setState(() {
        _risk = risk;
        _riskHistory = history;
        _savingRisk = false;
      });
      _snack('Risk analysis saved.');
    } catch (err) {
      if (!mounted) return;
      setState(() => _savingRisk = false);
      _snack(_friendly(err, 'Could not save risk analysis.'));
    }
  }

  Future<void> _previewSchedule() async {
    if (_previewingSchedule) return;
    setState(() {
      _previewingSchedule = true;
      _scheduleMessage = null;
    });
    try {
      final schedule = await _insightsApi.previewSmartSchedule(project: _project);
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _previewingSchedule = false;
        _scheduleMessage = schedule.tasks.isEmpty ? 'No schedulable tasks found.' : 'Preview ready for ${schedule.schedulableTaskCount} task(s).';
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _previewingSchedule = false;
        _scheduleMessage = _friendly(err, 'Could not preview schedule.');
      });
    }
  }

  Future<void> _applySchedule() async {
    if (_applyingSchedule || _schedule == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply smart schedule?'),
        content: const Text('This will update task due dates.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _applyingSchedule = true);
    try {
      await _insightsApi.applySmartSchedule(project: _project);
      if (!mounted) return;
      setState(() {
        _applyingSchedule = false;
        _schedule = null;
      });
      widget.onProjectChanged?.call();
      await _refresh();
      _snack('Smart schedule applied.');
    } catch (err) {
      if (!mounted) return;
      setState(() => _applyingSchedule = false);
      _snack(_friendly(err, 'Could not apply smart schedule.'));
    }
  }

  Future<void> _requestReport() async {
    if (_requestingReport) return;
    setState(() => _requestingReport = true);
    try {
      await ApiClient.postJson('/reports/projects/${_project.projectId}/request');
      if (!mounted) return;
      setState(() {
        _requestingReport = false;
        _reportStatus = 'pending';
      });
      _snack('Report request sent to admin.');
    } catch (err) {
      if (!mounted) return;
      setState(() => _requestingReport = false);
      _snack(_friendly(err, 'Could not request report.'));
    }
  }

  Future<void> _openReport() async {
    if (_openingReport) return;
    setState(() => _openingReport = true);
    try {
      final data = await ApiClient.get('/reports/projects/${_project.projectId}/latest');
      if (!mounted) return;
      setState(() => _openingReport = false);
      _showReportSheet(_map(data));
    } catch (err) {
      if (!mounted) return;
      setState(() => _openingReport = false);
      _snack(_friendly(err, 'Could not open report.'));
    }
  }

  double get _completion {
    if (_progress != null) return _progress!.project.completionPercentage;
    if (_tasks.isEmpty) return _project.isCompleted ? 100 : 0;
    return (_tasks.where((item) => item.task.isCompleted).length / _tasks.length) * 100;
  }

  int get _doneTasks => _tasks.where((item) => item.task.isCompleted).length;
  int get _overdueTasks => _tasks.where((item) => item.task.isOverdue).length;
  int get _activeTasks => _tasks.where((item) => !item.task.isCompleted).length;

  List<TaskListItem> get _filteredTasks {
    final filtered = _tasks.where((item) {
      final task = item.task;
      switch (_taskFilterIndex) {
        case 1:
          return !task.isCompleted;
        case 2:
          return task.isOverdue;
        case 3:
          return task.isCompleted;
        default:
          return true;
      }
    }).toList();
    filtered.sort(_compareTasks);
    return filtered;
  }

  int _compareTasks(TaskListItem left, TaskListItem right) {
    final leftTask = left.task;
    final rightTask = right.task;
    if (leftTask.isCompleted != rightTask.isCompleted) {
      return leftTask.isCompleted ? 1 : -1;
    }
    if (leftTask.isOverdue != rightTask.isOverdue) {
      return leftTask.isOverdue ? -1 : 1;
    }
    final leftDue = leftTask.dueDate;
    final rightDue = rightTask.dueDate;
    if (leftDue == null && rightDue == null) return leftTask.title.compareTo(rightTask.title);
    if (leftDue == null) return 1;
    if (rightDue == null) return -1;
    return leftDue.compareTo(rightDue);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(pageX, 14, pageX, 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Project Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
              ),
              if (_loading) Padding(padding: const EdgeInsets.symmetric(horizontal: pageX), child: LinearProgressIndicator(minHeight: 2, borderRadius: BorderRadius.circular(999))),
              if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(pageX, 8, pageX, 8), child: _message(_error!, true)),
              _tabs(colors),
              Expanded(
                child: TabBarView(
                  children: [
                    _tab([_projectCard(), _statsGrid(), if (_members.isNotEmpty) _membersCard()]),
                    _tab([_tasksCard()]),
                    _tab([_riskCard(), _scheduleCard(), _aiHistoryCard()]),
                    _tab([_reportCard(), _activityCard()]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs(ColorScheme colors) {
    return Container(
      height: 46,
      margin: const EdgeInsets.fromLTRB(pageX, 8, pageX, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: colors.surfaceVariant.withOpacity(.45), borderRadius: BorderRadius.circular(18)),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colors.onPrimary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        indicator: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(14)),
        tabs: const [Tab(text: 'Overview'), Tab(text: 'Tasks'), Tab(text: 'AI Tools'), Tab(text: 'Reports')],
      ),
    );
  }

  Widget _tab(List<Widget> children) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(pageX, 4, pageX, 24),
      itemBuilder: (_, index) => children[index],
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: children.length,
    ),
  );

  Widget _projectCard() {
    final colors = Theme.of(context).colorScheme;
    final percent = _completion.clamp(0, 100);
    final description = (_project.description ?? '').trim();
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: colors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(15)), child: Icon(_project.isTeamProject ? Icons.groups_2_rounded : Icons.folder_rounded, color: colors.primary)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_project.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 4),
          Text('${_project.statusLabel} • ${_project.projectTypeLabel} • ${_project.deadlineLabel}', style: _muted()),
        ])),
      ]),
      if (description.isNotEmpty) ...[const SizedBox(height: 12), _brief(description)],
      const SizedBox(height: 12),
      Row(children: [Text('${percent.round()}% complete', style: _bold()), const Spacer(), Text('$_doneTasks/${_tasks.length} tasks', style: _muted())]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: percent / 100, minHeight: 8)),
    ]));
  }

  Widget _brief(String value) {
    final colors = Theme.of(context).colorScheme;
    final cleaned = value.replaceFirst('AI planning brief', '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: colors.primary.withOpacity(.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.primary.withOpacity(.10))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.auto_awesome_rounded, size: 16, color: colors.primary), const SizedBox(width: 6), Text('AI planning brief', style: _bold())]),
        const SizedBox(height: 7),
        Text(cleaned, style: _muted()),
      ]),
    );
  }

  Widget _statsGrid() => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    childAspectRatio: 2.45,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    children: [_stat('Tasks', '${_tasks.length}', Icons.list_alt_rounded), _stat('Completed', '$_doneTasks', Icons.check_circle_rounded), _stat('Overdue', '$_overdueTasks', Icons.timer_off_rounded), _stat('Members', '${_members.length}', Icons.groups_rounded)],
  );

  Widget _riskCard() {
    final latest = _riskHistory.isNotEmpty ? _riskHistory.first : null;
    final level = _risk?.riskLevel ?? _text(latest ?? const <String, dynamic>{}, 'risk_level', fallback: 'unknown');
    return _section('Risk Analysis', level == 'unknown' ? 'Not analyzed yet' : '${level.toUpperCase()} risk', Icons.warning_amber_rounded, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_risk == null && latest == null) Text('No risk analysis yet.', style: _muted()),
      if (latest != null) _banner('Latest saved • ${_formatDateText(_text(latest, 'created_at'))}', _riskColor(level)),
      if (_risk != null) ...[const SizedBox(height: 8), _banner('${_risk!.predictedDelayDays} predicted delay days • ${_risk!.daysUntilDeadline} days until deadline', _riskColor(level)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [_pill('Overdue', '${_risk!.overdueTasks}'), _pill('Blocked', '${_risk!.blockedTasks}'), _pill('Remaining', '${_risk!.remainingEstimatedHours.toStringAsFixed(1)}h'), _pill('Done', '${_risk!.completedTasks}/${_risk!.totalTasks}')]), if (_risk!.reason.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_risk!.reason.trim(), style: _muted())), if (_risk!.recommendation.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Recommendation: ${_risk!.recommendation.trim()}', style: _primarySmall()))],
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _savingRisk ? null : _saveRiskAnalysis, icon: _savingRisk ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_as_rounded), label: Text(_savingRisk ? 'Saving...' : 'Analyze and save'))),
    ]));
  }

  Widget _scheduleCard() {
    final p = _schedule;
    return _section('Smart Schedule', p == null ? 'Preview better due dates' : '${p.schedulableTaskCount} schedulable task(s)', Icons.event_available_rounded, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _previewingSchedule ? null : _previewSchedule, icon: _previewingSchedule ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_motion_rounded), label: Text(_previewingSchedule ? 'Previewing...' : 'Preview'))), const SizedBox(width: 8), Expanded(child: ElevatedButton.icon(onPressed: _applyingSchedule || p == null ? null : _applySchedule, icon: _applyingSchedule ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.done_all_rounded), label: Text(_applyingSchedule ? 'Applying...' : 'Apply')))]),
      if (_scheduleMessage != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_scheduleMessage!, style: _muted())),
      if (p != null) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [_pill('Capacity', '${p.dailyCapacityHours.toStringAsFixed(1)}h/day'), _pill('Tasks', '${p.schedulableTaskCount}/${p.totalTasks}'), _pill('Done', '${p.completedTaskCount}')]), const SizedBox(height: 10), for (final item in p.tasks.take(5)) _line(item.title, '${item.priority} • ${item.estimatedHours.toStringAsFixed(1)}h • ${_formatDateTime(item.suggestedDueDate)}', item.isAfterProjectDeadline ? Icons.warning_amber_rounded : Icons.event_rounded)] else Padding(padding: const EdgeInsets.only(top: 10), child: Text('Preview first, then apply the suggested due dates.', style: _muted())),
    ]));
  }

  Widget _aiHistoryCard() => _section('AI Plan History', _aiPlans.isEmpty ? 'No AI plans yet' : '${_aiPlans.length} saved AI plan(s)', Icons.auto_awesome_rounded, _aiPlans.isEmpty ? Text('Generated AI plans for this project will appear here.', style: _muted()) : Column(children: [for (final plan in _aiPlans.take(4)) _tapLine(plan.summary, '${plan.generatedTaskCount} generated task(s) • ${_formatDateTime(plan.createdAt)}', Icons.psychology_alt_rounded, () => _showAiPlan(plan))]));

  Widget _tasksCard() {
    final filtered = _filteredTasks;
    final todo = filtered.where((item) => item.task.status == TaskStatus.todo).toList();
    final doing = filtered.where((item) => item.task.status == TaskStatus.inProgress).toList();
    final blocked = filtered.where((item) => item.task.status == TaskStatus.blocked).toList();
    final done = filtered.where((item) => item.task.status == TaskStatus.completed).toList();

    return _section(
      'Project Tasks',
      '${filtered.length} showing • $_activeTasks active • $_overdueTasks overdue',
      Icons.task_alt_rounded,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _taskSummaryStrip(),
        const SizedBox(height: 12),
        _taskFilters(),
        const SizedBox(height: 14),
        if (_tasks.isEmpty)
          _emptyState('No tasks in this project yet.', 'Generate a plan or add tasks from the main Tasks screen.')
        else if (filtered.isEmpty)
          _emptyState('No tasks match this filter.', 'Try another filter above.')
        else ...[
          if (todo.isNotEmpty) _taskGroup('To Do', todo, Icons.radio_button_unchecked_rounded),
          if (doing.isNotEmpty) _taskGroup('In Progress', doing, Icons.timelapse_rounded),
          if (blocked.isNotEmpty) _taskGroup('Blocked', blocked, Icons.block_rounded),
          if (done.isNotEmpty) _taskGroup('Completed', done, Icons.check_circle_rounded),
        ],
      ]),
    );
  }

  Widget _taskSummaryStrip() {
    return Row(children: [
      Expanded(child: _miniStat('All', '${_tasks.length}', Icons.list_alt_rounded)),
      const SizedBox(width: 8),
      Expanded(child: _miniStat('Active', '$_activeTasks', Icons.bolt_rounded)),
      const SizedBox(width: 8),
      Expanded(child: _miniStat('Done', '$_doneTasks', Icons.check_rounded)),
    ]);
  }

  Widget _taskFilters() {
    const labels = ['All', 'Active', 'Overdue', 'Done'];
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          ChoiceChip(
            selected: _taskFilterIndex == i,
            label: Text(labels[i]),
            labelStyle: TextStyle(fontWeight: FontWeight.w900, color: _taskFilterIndex == i ? colors.onPrimary : colors.onSurfaceVariant),
            selectedColor: colors.primary,
            backgroundColor: colors.surfaceVariant.withOpacity(.45),
            side: BorderSide(color: _taskFilterIndex == i ? Colors.transparent : colors.outlineVariant.withOpacity(.55)),
            onSelected: (_) => setState(() => _taskFilterIndex = i),
          ),
          if (i != labels.length - 1) const SizedBox(width: 8),
        ],
      ]),
    );
  }

  Widget _taskGroup(String title, List<TaskListItem> items, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
          const SizedBox(width: 6),
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text('${items.length}', style: _muted()),
        ]),
        const SizedBox(height: 8),
        for (final item in items) _taskLine(item),
      ]),
    );
  }

  Widget _reportCard() {
    final ready = _reportStatus == 'ready';
    final pending = _reportStatus == 'pending';
    final rejected = _reportStatus == 'rejected';
    return _section('Reports', ready ? 'Ready' : rejected ? 'Rejected' : pending ? 'Pending admin review' : 'No request yet', Icons.description_rounded, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_banner(ready ? 'Report ready. Open it inside Planora.' : rejected ? 'Request rejected. You can request again.' : pending ? 'Waiting for admin review.' : 'Ask admins to prepare a report.', ready ? Colors.green : rejected ? Theme.of(context).colorScheme.error : pending ? Colors.orange : Theme.of(context).colorScheme.primary), if (rejected && (_reportReason ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Reason: $_reportReason', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w800))), if (ready && _reportDate != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Latest report: $_reportDate', style: _muted())), const SizedBox(height: 12), if (ready) ...[SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _openingReport ? null : _openReport, icon: const Icon(Icons.visibility_rounded), label: Text(_openingReport ? 'Opening...' : 'View report in app'))), const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _requestingReport ? null : _requestReport, icon: const Icon(Icons.refresh_rounded), label: const Text('Request updated report')))] else SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _requestingReport || pending ? null : _requestReport, icon: Icon(pending ? Icons.hourglass_top_rounded : Icons.mail_outline_rounded), label: Text(_requestingReport ? 'Sending...' : pending ? 'Waiting for admin' : 'Request report from admin')))]));
  }

  Widget _activityCard() => _section('Activity Timeline', _activity.isEmpty ? 'No recent activity' : '${_activity.length} latest event(s)', Icons.timeline_rounded, _activity.isEmpty ? Text('Project activity will appear here.', style: _muted()) : Column(children: [for (final item in _activity) _line(item.message.trim().isEmpty ? item.eventType.replaceAll('_', ' ') : item.message.trim(), '${item.actorLabel} • ${_formatDateTime(item.createdAt)}', _activityIcon(item.eventType))]));
  Widget _membersCard() => _section('Members', '${_members.length} connected', Icons.groups_rounded, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final member in _members) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [CircleAvatar(child: Text(member.initials)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(member.displayName, style: _bold()), Text(member.email ?? member.roleLabel, style: _muted())])), Chip(label: Text(member.roleLabel))]))]));

  Widget _taskLine(TaskListItem item) {
    final task = item.task;
    final deleting = _deletingTaskId == task.taskId;
    final statusColor = _statusColor(task.status);
    final priorityColor = _priorityColor(task.priority);
    final progress = task.subtaskCount == 0 ? null : (task.completedSubtaskCount / task.subtaskCount).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(initialTask: item, onTaskChanged: () { _refresh(); widget.onProjectChanged?.call(); })));
          await _refresh();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.20),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: task.isOverdue ? Theme.of(context).colorScheme.error.withOpacity(.30) : Theme.of(context).colorScheme.outlineVariant.withOpacity(.45)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(task.title, style: _bold(), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _taskBadge(task.status.label, statusColor),
                  _taskBadge(task.priority.label, priorityColor),
                  _taskBadge(task.dueDateLabel, task.isOverdue ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                  if (task.subtaskCount > 0) _taskBadge('${task.completedSubtaskCount}/${task.subtaskCount} subtasks', Theme.of(context).colorScheme.tertiary),
                ]),
              ])),
              deleting
                  ? const Padding(padding: EdgeInsets.only(left: 8, top: 4), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(onPressed: () => _deleteTask(item), icon: const Icon(Icons.delete_outline_rounded), visualDensity: VisualDensity.compact),
            ]),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progress, minHeight: 5, color: statusColor)),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _deleteTask(TaskListItem item) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete task?'), content: Text('Delete "${item.task.title}"?'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')), FilledButton.tonal(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete'))]));
    if (confirmed != true) return;
    setState(() => _deletingTaskId = item.task.taskId);
    try { await _tasksApi.deleteTask(project: item.project, taskId: item.task.taskId); if (!mounted) return; setState(() { _tasks.removeWhere((task) => task.task.taskId == item.task.taskId); _deletingTaskId = null; }); widget.onProjectChanged?.call(); } catch (err) { if (!mounted) return; setState(() => _deletingTaskId = null); _snack(_friendly(err, 'Could not delete task.')); }
  }

  Widget _section(String title, String subtitle, IconData icon, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: colors.primary.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: colors.primary, size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)), Text(subtitle, style: _muted())]))]), const SizedBox(height: 14), child]));
  }

  Widget _card(Widget child) {
    final colors = Theme.of(context).colorScheme;
    return Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: colors.outlineVariant.withOpacity(.55)), boxShadow: [BoxShadow(color: colors.shadow.withOpacity(.04), blurRadius: 18, offset: const Offset(0, 8))]), child: child);
  }

  Widget _stat(String label, String value, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.outlineVariant.withOpacity(.50))), child: Row(children: [Icon(icon, color: colors.primary, size: 21), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1)), Text(label, style: _muted(), maxLines: 1, overflow: TextOverflow.ellipsis)]))]));
  }

  Widget _miniStat(String label, String value, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: colors.primary.withOpacity(.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.primary.withOpacity(.10))), child: Row(children: [Icon(icon, color: colors.primary, size: 17), const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, height: 1)), Text(label, style: _muted(), maxLines: 1, overflow: TextOverflow.ellipsis)]))]));
  }

  Widget _taskBadge(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.18))), child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w900)));
  Widget _emptyState(String title, String subtitle) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.25), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _bold()), const SizedBox(height: 4), Text(subtitle, style: _muted())]));
  Widget _banner(String text, Color color) => Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(17), border: Border.all(color: color.withOpacity(.18))), child: Text(text, style: _muted()?.copyWith(fontWeight: FontWeight.w800)));
  Widget _pill(String label, String value) => Chip(label: Text('$label: $value'));
  Widget _line(String title, String subtitle, IconData icon) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary, size: 19), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _bold(), maxLines: 1, overflow: TextOverflow.ellipsis), Text(subtitle, style: _muted(), maxLines: 1, overflow: TextOverflow.ellipsis)]))]));
  Widget _tapLine(String title, String subtitle, IconData icon, VoidCallback onTap) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _bold(), maxLines: 2, overflow: TextOverflow.ellipsis), Text(subtitle, style: _muted(), maxLines: 1, overflow: TextOverflow.ellipsis)])), const Icon(Icons.chevron_right_rounded)]))));
  Widget _message(String value, bool isError) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: (isError ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer).withOpacity(.35), borderRadius: BorderRadius.circular(18)), child: Text(value));
  TextStyle? _muted() => Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, height: 1.35);
  TextStyle? _primarySmall() => Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, height: 1.35);
  TextStyle? _bold() => Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900);

  Color _riskColor(String level) {
    final value = level.toLowerCase();
    if (value.contains('high')) return Theme.of(context).colorScheme.error;
    if (value.contains('medium')) return Colors.orange;
    if (value.contains('low')) return Colors.green;
    return Theme.of(context).colorScheme.primary;
  }

  Color _statusColor(TaskStatus status) {
    final colors = Theme.of(context).colorScheme;
    switch (status) {
      case TaskStatus.todo:
        return colors.primary;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.blocked:
        return colors.error;
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
    }
  }

  IconData _activityIcon(String type) {
    final value = type.toLowerCase();
    if (value.contains('task')) return Icons.task_alt_rounded;
    if (value.contains('comment')) return Icons.chat_bubble_outline_rounded;
    if (value.contains('attachment')) return Icons.attach_file_rounded;
    if (value.contains('report')) return Icons.description_rounded;
    return Icons.bolt_rounded;
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  String _formatDateText(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.isEmpty ? 'just now' : value;
    return _formatDateTime(parsed.toLocal());
  }

  void _showAiPlan(AiPlanHistoryModel plan) {
    final generatedTasks = plan.generatedPlan['tasks'];
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) => DraggableScrollableSheet(expand: false, initialChildSize: .75, builder: (context, controller) => ListView(controller: controller, padding: const EdgeInsets.all(20), children: [Text('AI Plan Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 12), Text(plan.summary), const SizedBox(height: 8), Text('Generated ${_formatDateTime(plan.createdAt)}'), if (plan.inputPrompt.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Prompt: ${plan.inputPrompt.trim()}')), if (generatedTasks is List && generatedTasks.isNotEmpty) ...[const SizedBox(height: 16), Text('Generated tasks', style: _bold()), for (final raw in generatedTasks.take(20)) _line(_text(_map(raw), 'title', fallback: 'Untitled task'), _text(_map(raw), 'description'), Icons.task_alt_rounded)]])));
  }

  void _showReportSheet(Map<String, dynamic> report) {
    final projectData = _map(report['project']);
    final progressData = _map(report['progress']);
    final title = _text(projectData, 'title', fallback: _project.title);
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) => DraggableScrollableSheet(expand: false, initialChildSize: .70, builder: (context, controller) => ListView(controller: controller, padding: const EdgeInsets.all(20), children: [Text('Project Report', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 12), Text(title, style: _bold()), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [_pill('Completion', '${_num(progressData, "completion_percentage").round()}%'), _pill('Completed', '${_num(progressData, "completed_tasks").round()}'), _pill('Overdue', '${_num(progressData, "overdue_tasks").round()}')])])));
  }
}
