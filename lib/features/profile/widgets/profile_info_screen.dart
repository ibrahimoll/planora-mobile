import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';
import '../data/profile_info_content.dart';
import '../models/profile_info_section.dart';

class ProfileInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? body;
  final List<ProfileInfoSection>? sections;

  const ProfileInfoScreen({
    super.key,
    required this.title,
    required this.icon,
    this.body,
    this.sections,
  }) : assert(body != null || sections != null);

  List<Widget> buildContent(BuildContext context) {
    final infoSections = sections ?? ProfileInfoContent.sectionsForTitle(title);

    if (infoSections == null || infoSections.isEmpty) {
      return [
        Text(
          body ?? '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _mutedColor(context),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
        ),
      ];
    }

    return [
      for (var index = 0; index < infoSections.length; index++) ...[
        if (index > 0) const SizedBox(height: 18),
        Text(
          infoSections[index].title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 7),
        Text(
          infoSections[index].body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _mutedColor(context),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (title == 'Subscription') {
      return const _SubscriptionInfoScreen();
    }

    if (title == 'Billing & Invoices') {
      return const _BillingInvoicesInfoScreen();
    }

    final isDark = PlanoraTheme.isDark(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? PlanoraTheme.darkSurface
                          : PlanoraTheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? PlanoraTheme.darkBorder
                            : PlanoraTheme.border,
                      ),
                      boxShadow: PlanoraTheme.cardShadowFor(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            icon,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 16),
                        ...buildContent(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionInfoScreen extends StatefulWidget {
  const _SubscriptionInfoScreen();

  @override
  State<_SubscriptionInfoScreen> createState() => _SubscriptionInfoScreenState();
}

class _SubscriptionInfoScreenState extends State<_SubscriptionInfoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<String> _features = [
    'Projects and task management',
    'Team collaboration',
    'Invitations and comments',
    'Notifications',
    'Profile and account settings',
    'Attachments, when enabled',
    'AI planning, when available',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget buildHeader(BuildContext context) {
    return _PageHeader(
      title: 'Subscription',
      onBack: () => Navigator.of(context).pop(),
    );
  }

  Widget buildHeroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroIcon(icon: Icons.workspace_premium_rounded),
              const Spacer(),
              const _LightPill(
                icon: Icons.check_circle_rounded,
                label: 'Active',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Planora Beta Access',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Standard beta workspace experience. Free while Planora is in beta.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Expanded(child: _HeroMeta(label: 'Price', value: 'Free')),
                SizedBox(width: 10),
                Expanded(child: _HeroMeta(label: 'Access', value: 'Beta')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCurrentPlanCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.verified_outlined, title: 'Current plan'),
          SizedBox(height: 14),
          _InfoRow(label: 'Plan', value: 'Beta Access'),
          _InfoRow(label: 'Status', value: 'Active'),
          _InfoRow(label: 'Price', value: 'Free during beta'),
          _InfoRow(label: 'Renewal', value: 'Not applicable'),
        ],
      ),
    );
  }

  Widget buildFeaturesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.auto_awesome_rounded,
            title: 'Included in beta',
          ),
          const SizedBox(height: 14),
          for (final feature in _features) ...[
            _CheckLine(text: feature),
            if (feature != _features.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget buildFutureCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.trending_up_rounded,
            title: 'Future plans',
          ),
          const SizedBox(height: 12),
          Text(
            'Paid plans may be added later for larger teams, advanced AI usage, additional storage, or workspace-level features.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedColor(context),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          _SupportNote(
            text:
                'Questions about access? Contact ${ProfileInfoContent.betaSupportEmail}.',
          ),
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  buildHeader(context),
                  const SizedBox(height: 18),
                  _Reveal(
                    controller: _controller,
                    index: 0,
                    child: buildHeroCard(context),
                  ),
                  const SizedBox(height: 18),
                  _Reveal(
                    controller: _controller,
                    index: 1,
                    child: buildCurrentPlanCard(context),
                  ),
                  const SizedBox(height: 14),
                  _Reveal(
                    controller: _controller,
                    index: 2,
                    child: buildFeaturesCard(context),
                  ),
                  const SizedBox(height: 14),
                  _Reveal(
                    controller: _controller,
                    index: 3,
                    child: buildFutureCard(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BillingInvoicesInfoScreen extends StatefulWidget {
  const _BillingInvoicesInfoScreen();

  @override
  State<_BillingInvoicesInfoScreen> createState() =>
      _BillingInvoicesInfoScreenState();
}

class _BillingInvoicesInfoScreenState extends State<_BillingInvoicesInfoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<String> _availabilityNotes = [
    'No payment method is required during beta',
    'No invoices have been generated yet',
    'No upgrade, downgrade, or cancellation flow is active',
    'Billing can be connected later when the backend exposes it',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget buildHeroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroIcon(icon: Icons.receipt_long_rounded),
              const Spacer(),
              const _LightPill(
                icon: Icons.info_outline_rounded,
                label: 'Beta',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Billing is not available yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Planora beta does not require payments. Invoice history will appear here only after production billing is added.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Expanded(child: _HeroMeta(label: 'Payment', value: 'Not needed')),
                SizedBox(width: 10),
                Expanded(child: _HeroMeta(label: 'Invoices', value: 'None')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Billing status',
          ),
          SizedBox(height: 14),
          _InfoRow(label: 'Billing', value: 'Inactive in beta'),
          _InfoRow(label: 'Payment method', value: 'None required'),
          _InfoRow(label: 'Invoice history', value: 'Unavailable'),
          _InfoRow(label: 'Charges', value: '0 during beta'),
        ],
      ),
    );
  }

  Widget buildAvailabilityCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.fact_check_outlined,
            title: 'What this means',
          ),
          const SizedBox(height: 14),
          for (final note in _availabilityNotes) ...[
            _CheckLine(text: note),
            if (note != _availabilityNotes.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget buildFutureCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.upcoming_outlined,
            title: 'Future billing support',
          ),
          const SizedBox(height: 12),
          Text(
            'When Planora introduces production billing, this page can show payment methods, invoice downloads, billing history, subscription charges, and plan management actions.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedColor(context),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          _SupportNote(
            text:
                'Billing questions? Contact ${ProfileInfoContent.betaSupportEmail}.',
          ),
        ],
      ),
    );
  }

  Widget buildComingSoonCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.construction_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Invoice downloads and payment management are coming later with backend billing support.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedColor(context),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
            ),
          ),
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  _PageHeader(
                    title: 'Billing & Invoices',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 18),
                  _Reveal(
                    controller: _controller,
                    index: 0,
                    child: buildHeroCard(context),
                  ),
                  const SizedBox(height: 18),
                  _Reveal(
                    controller: _controller,
                    index: 1,
                    child: buildStatusCard(context),
                  ),
                  const SizedBox(height: 14),
                  _Reveal(
                    controller: _controller,
                    index: 2,
                    child: buildAvailabilityCard(context),
                  ),
                  const SizedBox(height: 14),
                  _Reveal(
                    controller: _controller,
                    index: 3,
                    child: buildComingSoonCard(context),
                  ),
                  const SizedBox(height: 14),
                  _Reveal(
                    controller: _controller,
                    index: 4,
                    child: buildFutureCard(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PageHeader({
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Widget child;

  const _Reveal({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.08).clamp(0.0, 0.72).toDouble();
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }
}

class _HeroIcon extends StatelessWidget {
  final IconData icon;

  const _HeroIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _LightPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LightPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedColor(context),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  final String text;

  const _CheckLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: PlanoraTheme.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 15,
            color: PlanoraTheme.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _SupportNote extends StatelessWidget {
  final String text;

  const _SupportNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.support_agent_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedColor(context),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _mutedColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkTextMuted
      : PlanoraTheme.textSecondary;
}

BoxDecoration _cardDecoration(BuildContext context) {
  final isDark = PlanoraTheme.isDark(context);

  return BoxDecoration(
    color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
    ),
    boxShadow: PlanoraTheme.cardShadowFor(context),
  );
}
