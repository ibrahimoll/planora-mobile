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

  List<ProfileInfoSection> get resolvedSections {
    final professionalSections = _professionalSectionsForTitle(title);
    if (professionalSections != null) return professionalSections;

    final directSections = sections ?? ProfileInfoContent.sectionsForTitle(title);
    if (directSections != null && directSections.isNotEmpty) {
      return directSections;
    }

    return [
      ProfileInfoSection(
        title: title,
        body: body ?? 'Information for this page is not available yet.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final details = _pageDetailsForTitle(title);
    final pageSections = resolvedSections;

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
                    title: title,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 18),
                  _RevealItem(
                    index: 0,
                    child: _HeroSummaryCard(
                      title: title,
                      icon: icon,
                      description: details.description,
                      badgeLabel: details.badgeLabel,
                      secondaryLabel: details.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var index = 0; index < pageSections.length; index++) ...[
                    _RevealItem(
                      index: index + 1,
                      child: _InfoSectionCard(
                        section: pageSections[index],
                        icon: _sectionIconFor(title, pageSections[index].title),
                        accent: _sectionAccentFor(title, pageSections[index].title),
                      ),
                    ),
                    if (index != pageSections.length - 1) const SizedBox(height: 12),
                  ],
                  if (details.footerNote != null) ...[
                    const SizedBox(height: 14),
                    _RevealItem(
                      index: pageSections.length + 1,
                      child: _FooterNote(text: details.footerNote!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageDetails {
  final String description;
  final String badgeLabel;
  final String? secondaryLabel;
  final String? footerNote;

  const _PageDetails({
    required this.description,
    required this.badgeLabel,
    this.secondaryLabel,
    this.footerNote,
  });
}

_PageDetails _pageDetailsForTitle(String title) {
  switch (title) {
    case 'Help & Support':
      return const _PageDetails(
        description:
            'Get clear guidance for reporting issues, requesting help, and understanding what support is available during the Planora beta.',
        badgeLabel: 'Beta support',
        secondaryLabel: 'Email support',
        footerNote:
            'Support requests are handled manually during beta, so include screenshots and exact steps whenever possible.',
      );
    case 'Privacy Policy':
      return const _PageDetails(
        description:
            'Review how Planora handles account, workspace, notification, attachment, and AI-related data inside the app.',
        badgeLabel: 'Privacy',
        secondaryLabel: 'Data transparency',
        footerNote:
            'This in-app summary is written for the beta version and should be updated before a public production release.',
      );
    case 'Terms of Service':
      return const _PageDetails(
        description:
            'Understand the main rules for using Planora beta, keeping your account secure, and using workspace features responsibly.',
        badgeLabel: 'Beta terms',
        secondaryLabel: 'Responsible use',
        footerNote:
            'These beta terms are a practical app summary and should be reviewed before public launch.',
      );
    case 'Subscription':
      return const _PageDetails(
        description:
            'Your current Planora access is free beta access. Paid plans, renewals, and upgrade controls are not active yet.',
        badgeLabel: 'Active',
        secondaryLabel: 'Free beta',
        footerNote:
            'Subscription controls can be connected later when paid workspace plans are added to the backend.',
      );
    case 'Billing & Invoices':
      return const _PageDetails(
        description:
            'Billing is intentionally disabled during the beta period, so there are no payment methods, invoices, or renewal charges to manage.',
        badgeLabel: 'Not active',
        secondaryLabel: 'No charges',
        footerNote:
            'When billing launches, this page should show payment method status, invoice history, and plan ownership details.',
      );
    case 'Email Preferences':
      return const _PageDetails(
        description:
            'Review how email communication should work for account updates, workspace activity, reminders, and beta announcements.',
        badgeLabel: 'Preferences',
        secondaryLabel: 'Backend pending',
        footerNote:
            'The UI is ready for preference categories. Persisting toggles requires backend preference endpoints.',
      );
    case 'Notification Settings':
      return const _PageDetails(
        description:
            'Understand the notification categories Planora should support across in-app alerts, reminders, comments, and team updates.',
        badgeLabel: 'Notifications',
        secondaryLabel: 'Default behavior',
        footerNote:
            'Detailed per-channel controls can be enabled when the backend exposes notification preference storage.',
      );
    default:
      return _PageDetails(
        description: 'Review the current $title information for your Planora account.',
        badgeLabel: 'Info',
      );
  }
}

List<ProfileInfoSection>? _professionalSectionsForTitle(String title) {
  switch (title) {
    case 'Help & Support':
      return const [
        ProfileInfoSection(
          title: 'How to get help',
          body:
              'For beta support, contact Planora at ${ProfileInfoContent.betaSupportEmail}. Explain what you were trying to do, what happened instead, and whether the issue happens again after restarting the app.',
        ),
        ProfileInfoSection(
          title: 'Include these details',
          body:
              'Account email or username\nScreen name where the problem happened\nExact action that caused the issue\nError message, if one appeared\nScreenshot or screen recording, if possible\nDevice and app build, when available',
        ),
        ProfileInfoSection(
          title: 'What support can help with',
          body:
              'Login, registration, and password issues\nProfile and account information problems\nProjects, tasks, teams, and invitations\nNotifications or missing updates\nAttachment upload issues\nBugs, crashes, loading problems, or visual glitches',
        ),
        ProfileInfoSection(
          title: 'Before reporting a bug',
          body:
              'Check your internet connection\nPull the latest app version\nRestart the app\nTry the action again once\nWrite down the exact steps before sending the report',
        ),
      ];
    case 'Privacy Policy':
      return const [
        ProfileInfoSection(
          title: 'Information Planora uses',
          body:
              'Name, username, email, profile picture, role, verification status, and account dates\nProjects, tasks, teams, comments, invitations, and workspace activity\nNotifications, attachments, and AI planning requests when those features are used\nBasic technical information needed to keep the service secure and functional',
        ),
        ProfileInfoSection(
          title: 'Why the data is used',
          body:
              'To sign you in securely\nTo show your profile to workspace members\nTo sync projects, tasks, and collaboration data across devices\nTo send relevant account or workspace notifications\nTo troubleshoot bugs and improve beta stability',
        ),
        ProfileInfoSection(
          title: 'Workspace visibility',
          body:
              'Your profile name, username, profile picture, and workspace actions may be visible to teammates where collaboration features require it. Private account credentials are never shown to workspace members.',
        ),
        ProfileInfoSection(
          title: 'AI features',
          body:
              'When you use AI planning tools, the project or task details you provide may be processed to generate plans, schedules, summaries, or suggestions. Do not enter sensitive information that should not be used for planning assistance.',
        ),
        ProfileInfoSection(
          title: 'Your control',
          body:
              'Keep your profile information accurate\nUse a strong password\nAvoid uploading sensitive files during beta\nContact support if you need help with account data or privacy questions',
        ),
      ];
    case 'Terms of Service':
      return const [
        ProfileInfoSection(
          title: 'Beta access',
          body:
              'Planora is currently beta software. Features may change, be limited, be removed, or become temporarily unavailable while the product is being tested and improved.',
        ),
        ProfileInfoSection(
          title: 'Account responsibility',
          body:
              'You are responsible for keeping your login credentials secure and for the activity that happens under your account. Report unauthorized access or suspicious account behavior as soon as possible.',
        ),
        ProfileInfoSection(
          title: 'Acceptable use',
          body:
              'Do not attempt unauthorized access\nDo not upload harmful, illegal, or abusive content\nDo not attack, overload, or interfere with Planora services\nDo not misuse invitations, teams, comments, notifications, or AI features',
        ),
        ProfileInfoSection(
          title: 'Workspace content',
          body:
              'Only upload files, profile pictures, and workspace content that you have the right to use. Content should be appropriate for a productivity and project management workspace.',
        ),
        ProfileInfoSection(
          title: 'Service changes',
          body:
              'During beta, Planora may update screens, change APIs, limit features, reset test data, or adjust access while the app is being prepared for a more stable release.',
        ),
      ];
    case 'Subscription':
      return const [
        ProfileInfoSection(
          title: 'Current plan',
          body:
              'Plan: Beta Access\nStatus: Active\nPrice: Free during beta\nRenewal: Not applicable\nBilling owner: Not required during beta',
        ),
        ProfileInfoSection(
          title: 'Included during beta',
          body:
              'Projects and task management\nTeam collaboration\nInvitations and comments\nNotifications\nProfile and account settings\nAttachments when enabled\nAI planning features when available',
        ),
        ProfileInfoSection(
          title: 'Future plans',
          body:
              'Paid plans may be added later for larger teams, advanced AI usage, storage limits, workspace analytics, admin controls, or premium collaboration features.',
        ),
      ];
    case 'Billing & Invoices':
      return const [
        ProfileInfoSection(
          title: 'Billing status',
          body:
              'Billing is not active for Planora beta accounts. You do not need to add a payment method, and no invoice history is available yet.',
        ),
        ProfileInfoSection(
          title: 'What will appear here later',
          body:
              'Payment method status\nBilling owner and workspace plan\nInvoice history\nTax or company billing details\nUpgrade, downgrade, and renewal information',
        ),
        ProfileInfoSection(
          title: 'No beta charges',
          body:
              'Planora beta access is currently free. If paid plans are introduced later, the app should clearly show plan price, renewal date, billing owner, and invoice records before charging users.',
        ),
      ];
    case 'Email Preferences':
      return const [
        ProfileInfoSection(
          title: 'Preference categories',
          body:
              'Account and security emails\nWorkspace invitations\nTask assignment and due-date emails\nProject updates and summaries\nProduct announcements and beta updates',
        ),
        ProfileInfoSection(
          title: 'Recommended behavior',
          body:
              'Security emails should always stay enabled. Workspace and marketing emails can become user-controlled when backend preference storage is available.',
        ),
        ProfileInfoSection(
          title: 'Backend status',
          body:
              'The mobile page is ready for professional preference categories, but saving individual email toggles requires backend endpoints for email notification preferences.',
        ),
      ];
    case 'Notification Settings':
      return const [
        ProfileInfoSection(
          title: 'Notification categories',
          body:
              'Task assignments\nDue-date reminders\nProject updates\nTeam invitations\nComments and mentions\nSystem and account alerts\nAI planning results when available',
        ),
        ProfileInfoSection(
          title: 'Current behavior',
          body:
              'During beta, notification delivery uses the current backend defaults. Detailed per-category and per-channel controls are not fully exposed yet.',
        ),
        ProfileInfoSection(
          title: 'Future controls',
          body:
              'In-app alerts\nPush notifications\nEmail notifications\nQuiet hours\nProject-specific notification rules\nTeam or workspace-level notification defaults',
        ),
      ];
    default:
      return null;
  }
}

IconData _sectionIconFor(String pageTitle, String sectionTitle) {
  final text = '$pageTitle $sectionTitle'.toLowerCase();

  if (text.contains('contact') || text.contains('help')) {
    return Icons.support_agent_rounded;
  }
  if (text.contains('privacy') || text.contains('data') || text.contains('secure')) {
    return Icons.shield_outlined;
  }
  if (text.contains('terms') || text.contains('acceptable') || text.contains('responsibility')) {
    return Icons.gavel_rounded;
  }
  if (text.contains('billing') || text.contains('invoice') || text.contains('payment')) {
    return Icons.receipt_long_outlined;
  }
  if (text.contains('plan') || text.contains('subscription') || text.contains('included')) {
    return Icons.workspace_premium_outlined;
  }
  if (text.contains('email')) {
    return Icons.mail_outline_rounded;
  }
  if (text.contains('notification') || text.contains('reminder')) {
    return Icons.notifications_none_rounded;
  }
  if (text.contains('ai')) {
    return Icons.auto_awesome_rounded;
  }
  if (text.contains('future')) {
    return Icons.trending_up_rounded;
  }

  return Icons.info_outline_rounded;
}

Color? _sectionAccentFor(String pageTitle, String sectionTitle) {
  final text = '$pageTitle $sectionTitle'.toLowerCase();
  if (text.contains('no beta charges') || text.contains('active')) {
    return PlanoraTheme.success;
  }
  if (text.contains('not active') || text.contains('unavailable') || text.contains('backend')) {
    return PlanoraTheme.warning;
  }
  return null;
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
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              width: 44,
              height: 44,
              decoration: _circleButtonDecoration(context),
              child: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final String badgeLabel;
  final String? secondaryLabel;

  const _HeroSummaryCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.badgeLabel,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              _HeroIcon(icon: icon),
              const Spacer(),
              _HeroPill(icon: Icons.verified_rounded, label: badgeLabel),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      secondaryLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoSectionCard extends StatelessWidget {
  final ProfileInfoSection section;
  final IconData icon;
  final Color? accent;

  const _InfoSectionCard({
    required this.section,
    required this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? Theme.of(context).colorScheme.primary;
    final lines = section.body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final useBullets = lines.length > 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: effectiveAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: effectiveAccent.withValues(alpha: 0.12)),
                ),
                child: Icon(icon, size: 20, color: effectiveAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (useBullets)
            Column(
              children: [
                for (var index = 0; index < lines.length; index++) ...[
                  _BulletLine(text: lines[index], color: effectiveAccent),
                  if (index != lines.length - 1) const SizedBox(height: 10),
                ],
              ],
            )
          else
            Text(
              section.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _mutedColor(context),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
            ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  final Color color;

  const _BulletLine({required this.text, required this.color});

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
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(Icons.check_rounded, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedColor(context),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _FooterNote extends StatelessWidget {
  final String text;

  const _FooterNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.tips_and_updates_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
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

class _RevealItem extends StatelessWidget {
  final int index;
  final Widget child;

  const _RevealItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: animatedChild,
          ),
        );
      },
      child: child,
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

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

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

BoxDecoration _circleButtonDecoration(BuildContext context) {
  final isDark = PlanoraTheme.isDark(context);

  return BoxDecoration(
    color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(
      color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
    ),
    boxShadow: PlanoraTheme.cardShadowFor(context),
  );
}

BoxDecoration _cardDecoration(BuildContext context) {
  final isDark = PlanoraTheme.isDark(context);

  return BoxDecoration(
    color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
    ),
    boxShadow: PlanoraTheme.cardShadowFor(context),
  );
}

Color _mutedColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkTextMuted
      : PlanoraTheme.textSecondary;
}
