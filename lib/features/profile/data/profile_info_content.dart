import '../models/profile_info_section.dart';

class ProfileInfoContent {
  const ProfileInfoContent._();

  static const List<ProfileInfoSection> helpSupport = [
    ProfileInfoSection(
      title: 'Beta support',
      body:
          'Planora is currently in beta. Some features may still be incomplete, limited, or under active testing. If something does not work as expected, report the issue with enough detail so it can be reproduced and fixed.',
    ),
    ProfileInfoSection(
      title: 'What to include in a support request',
      body:
          'When reporting an issue, include your account email, username, the screen you were using, the project or task name if relevant, the exact action you tried, and the error message you saw.',
    ),
    ProfileInfoSection(
      title: 'Account and login issues',
      body:
          'For login, password, verification, or profile problems, mention whether the issue happened during login, registration, email verification, password reset, profile update, or password change.',
    ),
    ProfileInfoSection(
      title: 'Projects, tasks, and teams',
      body:
          'For project, task, team, invitation, or comment issues, include the project name, task title, team member involved if relevant, and whether the issue happened while creating, editing, deleting, assigning, or loading data.',
    ),
    ProfileInfoSection(
      title: 'AI planning issues',
      body:
          'For AI chat or AI planning issues, include what you asked Planora AI to do and what result you expected. Do not send passwords, private keys, financial secrets, or sensitive personal data in support messages or AI prompts.',
    ),
    ProfileInfoSection(
      title: 'Attachments and notifications',
      body:
          'For attachment problems, mention the file type and the action that failed. For notification issues, mention whether the problem is missing notifications, delayed notifications, or notifications that do not open the expected screen.',
    ),
    ProfileInfoSection(
      title: 'Basic troubleshooting',
      body:
          'Before reporting a bug, try refreshing the screen, checking your internet connection, closing and reopening the app, and signing in again if the session appears expired.',
    ),
    ProfileInfoSection(
      title: 'Known beta limitations',
      body:
          'Some settings are currently informational only. Advanced email preferences, per-channel notification settings, billing management, subscription management, and full account deletion are not fully exposed in the mobile app yet.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'Contact Planora support through the official support channel provided by the app or project owner. If this is a test build, send the report directly to the beta owner or developer.',
    ),
  ];

  static const List<ProfileInfoSection> privacyPolicy = [
    ProfileInfoSection(title: 'Last updated', body: 'June 14, 2026'),
    ProfileInfoSection(
      title: 'Overview',
      body:
          'Planora is an AI-powered project planning and collaboration app. This policy explains what information Planora handles to provide accounts, projects, tasks, teams, notifications, attachments, comments, and AI-assisted planning features.',
    ),
    ProfileInfoSection(
      title: 'Information we collect',
      body:
          'Planora may store account and profile information such as username, email address, full name, role, email verification status, profile picture, and account creation date. Planora also stores the content you create or share, including projects, tasks, teams, invitations, comments, attachments, notifications, and AI chat or planning messages.',
    ),
    ProfileInfoSection(
      title: 'How we use information',
      body:
          'Planora uses this information to authenticate users, load your profile, manage projects and tasks, support team collaboration, send in-app notifications, handle attachments, and provide AI-assisted planning responses based on the content you choose to submit.',
    ),
    ProfileInfoSection(
      title: 'AI-assisted planning',
      body:
          'When you use AI planning or chat features, the information you enter may be used to generate task suggestions, project breakdowns, summaries, or productivity recommendations. Do not include passwords, private keys, financial secrets, or sensitive personal information in AI messages, project descriptions, task details, or comments.',
    ),
    ProfileInfoSection(
      title: 'Team collaboration and shared content',
      body:
          'Content added to shared workspaces, teams, projects, tasks, comments, invitations, and attachments may be visible to other authorized users who are part of the same workspace or collaboration flow.',
    ),
    ProfileInfoSection(
      title: 'Local device storage',
      body:
          'Planora may store authentication tokens and remembered login identifiers locally using secure device storage so the app can keep you signed in and restore your session safely.',
    ),
    ProfileInfoSection(
      title: 'Security',
      body:
          'Planora uses the configured backend API and secure local storage patterns to protect account access. No app can guarantee absolute security, so users should keep their credentials private and avoid sharing sensitive secrets inside workspace content.',
    ),
    ProfileInfoSection(
      title: 'Data retention',
      body:
          'Planora keeps account, workspace, project, task, team, comment, attachment, notification, and AI planning data for as long as needed to provide the app experience, maintain collaboration history, troubleshoot issues, or satisfy operational requirements.',
    ),
    ProfileInfoSection(
      title: 'Your choices',
      body:
          'You can update supported profile information from the Profile page and change your password through the password screen. Features such as full account deletion, advanced privacy settings, and per-channel notification preferences are not currently exposed in the mobile app.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For privacy questions or support requests, contact Planora support through the official support channel provided by the app or project owner.',
    ),
    ProfileInfoSection(
      title: 'Legal review note',
      body:
          'This policy is provided for transparency inside Planora. For production release, review it with a qualified legal professional.',
    ),
  ];

  static const List<ProfileInfoSection> terms = [
    ProfileInfoSection(title: 'Last updated', body: 'June 14, 2026'),
    ProfileInfoSection(
      title: 'Acceptance of terms',
      body:
          'By using Planora, you agree to use the app responsibly for lawful project planning, task management, team collaboration, and AI-assisted productivity workflows.',
    ),
    ProfileInfoSection(
      title: 'Account responsibility',
      body:
          'You are responsible for keeping your login credentials secure and for all activity performed through your account. If you believe your account is no longer secure, change your password and contact support through the official support channel.',
    ),
    ProfileInfoSection(
      title: 'Workspace and team content',
      body:
          'You are responsible for the projects, tasks, teams, invitations, comments, attachments, and other content you create or share in Planora. Only upload or share content that you own or have permission to use.',
    ),
    ProfileInfoSection(
      title: 'AI-generated suggestions',
      body:
          'Planora may generate AI-assisted suggestions, project plans, task breakdowns, or productivity guidance. AI output should be reviewed before use and should not be treated as guaranteed, professional, legal, financial, medical, or security advice.',
    ),
    ProfileInfoSection(
      title: 'Acceptable use',
      body:
          'Do not use Planora to upload illegal content, abuse other users, share malware, expose secrets, violate intellectual property rights, disrupt the service, or attempt unauthorized access to accounts, systems, projects, teams, or backend data.',
    ),
    ProfileInfoSection(
      title: 'Attachments and shared files',
      body:
          'Attachments and shared files should only include content that is safe, relevant, and permitted to be shared with the intended workspace or team members.',
    ),
    ProfileInfoSection(
      title: 'Service availability',
      body:
          'Planora depends on mobile app services, the configured backend API, storage, and network availability. Some features may be unavailable during maintenance, outages, development changes, or unsupported backend states.',
    ),
    ProfileInfoSection(
      title: 'Limitation of responsibility',
      body:
          'Planora is provided to help organize work and improve productivity. You remain responsible for reviewing your plans, tasks, shared content, and decisions before relying on them.',
    ),
    ProfileInfoSection(
      title: 'Updates to these terms',
      body:
          'These terms may be updated as Planora evolves. Continued use of the app after updates means you accept the revised terms shown in the app.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For questions about these terms, contact Planora support through the official support channel provided by the app or project owner.',
    ),
    ProfileInfoSection(
      title: 'Legal review note',
      body:
          'This policy is provided for transparency inside Planora. For production release, review it with a qualified legal professional.',
    ),
  ];
}
