import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/planora_theme.dart';
import '../models/profile_info_section.dart';
import 'profile_api.dart';

Widget buildProfileSection(
  BuildContext context, {
  required String title,
  required List<dynamic> items,
}) {
  final isDark = PlanoraTheme.isDark(context);
  final mutedColor = isDark
      ? PlanoraTheme.darkTextMuted
      : PlanoraTheme.textSecondary;

  return TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 18),
          child: child,
        ),
      );
    },
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          for (var index = 0; index < items.length; index++) ...[
            _buildProfileActionTile(
              context,
              item: items[index],
              mutedColor: mutedColor,
            ),
            if (index != items.length - 1)
              Divider(
                height: 1,
                indent: 72,
                color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
              ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildProfileActionTile(
  BuildContext context, {
  required dynamic item,
  required Color mutedColor,
}) {
  final icon = item.icon as IconData;
  final title = item.title as String;
  final subtitle = item.subtitle as String;
  final originalOnTap = item.onTap as VoidCallback;
  final onTap = title == 'Edit Profile'
      ? () => _showLiveEditProfileSheet(context, fallbackOnTap: originalOnTap)
      : originalOnTap;

  return ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    minVerticalPadding: 8,
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
    ),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w900),
    ),
    subtitle: Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600),
    ),
    trailing: Icon(Icons.chevron_right_rounded, color: mutedColor),
  );
}

void _showLiveEditProfileSheet(
  BuildContext context, {
  required VoidCallback fallbackOnTap,
}) {
  const profileApi = ProfileApi();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final dynamic profileState = context.findAncestorStateOfType<State<StatefulWidget>>();

  dynamic user;
  try {
    user = profileState?.user;
  } catch (_) {
    user = null;
  }

  if (profileState == null || user == null) {
    fallbackOnTap();
    return;
  }

  final initialUsername = (user.username as String? ?? '').trim();
  final initialFullName = (user.fullName as String? ?? '').trim();
  final email = (user.email as String? ?? '').trim();
  final usernameController = TextEditingController(text: initialUsername);
  final fullNameController = TextEditingController(text: initialFullName);
  final picker = ImagePicker();

  String? currentProfilePic = user.profilePic as String?;
  bool isSaving = false;
  bool isUploadingPicture = false;
  bool isSheetClosing = false;

  bool validUsername(String value) {
    return RegExp(r'^[A-Za-z0-9_]{3,50}$').hasMatch(value.trim());
  }

  void closeSheet(NavigatorState sheetNavigator) {
    if (isSheetClosing) return;
    isSheetClosing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    if (sheetNavigator.canPop()) {
      sheetNavigator.pop();
    }
  }

  void applyUpdatedUser(dynamic updatedUser) {
    try {
      if (profileState.mounted == true) {
        profileState.setState(() {
          profileState.user = updatedUser;
        });
        profileState.widget.onUserUpdated?.call(updatedUser);
      }
    } catch (error, stackTrace) {
      debugPrint('Profile state refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final sheetNavigator = Navigator.of(sheetContext);

      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final fullName = fullNameController.text.trim();
          final username = usernameController.text.trim();
          final fullNameValid = fullName.isNotEmpty;
          final usernameValid = validUsername(username);
          final hasChanges =
              fullName != initialFullName || username != initialUsername;
          final canSave =
              fullNameValid &&
              usernameValid &&
              hasChanges &&
              !isSaving &&
              !isUploadingPicture &&
              !isSheetClosing;

          void refresh(String _) {
            if (isSheetClosing) return;
            setSheetState(() {});
          }

          Future<void> pickAndUploadPicture() async {
            if (isSaving || isUploadingPicture || isSheetClosing) return;
            FocusManager.instance.primaryFocus?.unfocus();

            final pickedFile = await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
              maxWidth: 1200,
              maxHeight: 1200,
            );

            if (pickedFile == null || !sheetContext.mounted || isSheetClosing) {
              return;
            }

            setSheetState(() {
              isUploadingPicture = true;
            });

            try {
              final updatedUser = await profileApi.uploadProfilePicture(
                file: pickedFile,
              );
              currentProfilePic = updatedUser.profilePic;
              applyUpdatedUser(updatedUser);

              if (!sheetContext.mounted || isSheetClosing) return;
              setSheetState(() {
                isUploadingPicture = false;
              });
              messenger?.showSnackBar(
                const SnackBar(content: Text('Profile picture updated.')),
              );
            } on ApiException catch (error) {
              if (sheetContext.mounted && !isSheetClosing) {
                setSheetState(() {
                  isUploadingPicture = false;
                });
              }
              messenger?.showSnackBar(SnackBar(content: Text(error.message)));
            } catch (error, stackTrace) {
              debugPrint('Profile picture upload failed: $error');
              debugPrintStack(stackTrace: stackTrace);
              if (sheetContext.mounted && !isSheetClosing) {
                setSheetState(() {
                  isUploadingPicture = false;
                });
              }
              messenger?.showSnackBar(
                const SnackBar(content: Text('Could not upload profile picture.')),
              );
            }
          }

          Future<void> submitProfileUpdate() async {
            if (!canSave) return;
            FocusManager.instance.primaryFocus?.unfocus();
            setSheetState(() {
              isSaving = true;
            });

            var saved = false;
            try {
              final updatedUser = await profileApi.updateProfile(
                username: username,
                fullName: fullName,
              );
              saved = true;
              currentProfilePic = updatedUser.profilePic;
              applyUpdatedUser(updatedUser);
              closeSheet(sheetNavigator);
              messenger?.showSnackBar(
                const SnackBar(content: Text('Profile updated successfully.')),
              );
            } on ApiException catch (error) {
              messenger?.showSnackBar(SnackBar(content: Text(error.message)));
            } catch (error, stackTrace) {
              debugPrint('Profile update failed: $error');
              debugPrintStack(stackTrace: stackTrace);
              messenger?.showSnackBar(
                const SnackBar(content: Text('Could not update profile.')),
              );
            } finally {
              if (!saved && !isSheetClosing && sheetContext.mounted) {
                setSheetState(() {
                  isSaving = false;
                });
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
              ),
              decoration: BoxDecoration(
                color: PlanoraTheme.isDark(sheetContext)
                    ? PlanoraTheme.darkBackground
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: PlanoraTheme.floatingShadowFor(sheetContext),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 18),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SheetGrabber(),
                      const SizedBox(height: 20),
                      _SheetHeader(
                        title: 'Edit Profile',
                        icon: Icons.edit_outlined,
                        onClose: isSaving || isUploadingPicture
                            ? null
                            : () => closeSheet(sheetNavigator),
                      ),
                      const SizedBox(height: 22),
                      _ProfilePreviewCard(
                        fullName: fullNameValid ? fullName : initialFullName,
                        username: usernameValid ? username : initialUsername,
                        email: email,
                        profilePic: currentProfilePic,
                        isUploadingPicture: isUploadingPicture,
                        onChangePicture: pickAndUploadPicture,
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'Tap the avatar or press Change picture to upload a profile photo.',
                          textAlign: TextAlign.center,
                          style: Theme.of(sheetContext).textTheme.bodySmall
                              ?.copyWith(
                                color: _profileMutedColor(sheetContext),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _SheetLabel('Full name'),
                      const SizedBox(height: 8),
                      _ProfileTextField(
                        controller: fullNameController,
                        hintText: 'Enter your full name',
                        icon: Icons.person_outline_rounded,
                        onChanged: refresh,
                      ),
                      const SizedBox(height: 8),
                      _EditProfileHint(
                        isValid: fullNameValid,
                        text: fullNameValid
                            ? 'This name will be shown on your profile.'
                            : 'Full name is required.',
                      ),
                      const SizedBox(height: 16),
                      const _SheetLabel('Username'),
                      const SizedBox(height: 8),
                      _ProfileTextField(
                        controller: usernameController,
                        hintText: 'Choose a username',
                        icon: Icons.alternate_email_rounded,
                        onChanged: refresh,
                      ),
                      const SizedBox(height: 8),
                      _EditProfileHint(
                        isValid: usernameValid,
                        text: usernameValid
                            ? 'Username looks good.'
                            : 'Use 3-50 letters, numbers, or underscores.',
                      ),
                      const SizedBox(height: 22),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: canSave || isSaving ? 1 : 0.55,
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: canSave ? submitProfileUpdate : null,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              isSaving ? 'Saving profile...' : 'Save Changes',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton(
                          onPressed: isSaving || isUploadingPicture
                              ? null
                              : () => closeSheet(sheetNavigator),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    usernameController.dispose();
    fullNameController.dispose();
  });
}

Color _profileMutedColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkTextMuted
      : PlanoraTheme.textSecondary;
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkBorder
              : PlanoraTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onClose;

  const _SheetHeader({
    required this.title,
    required this.icon,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String label;

  const _SheetLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _ProfilePreviewCard extends StatelessWidget {
  final String fullName;
  final String username;
  final String email;
  final String? profilePic;
  final bool isUploadingPicture;
  final VoidCallback onChangePicture;

  const _ProfilePreviewCard({
    required this.fullName,
    required this.username,
    required this.email,
    required this.profilePic,
    required this.isUploadingPicture,
    required this.onChangePicture,
  });

  String get initials {
    final source = fullName.trim().isNotEmpty ? fullName.trim() : username.trim();
    if (source.isEmpty) return 'P';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return source[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = PlanoraTheme.isDark(context);
    final imageUrl = profilePic?.trim();
    final canTap = !isUploadingPicture;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canTap ? onChangePicture : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? ClipOval(
                                  key: ValueKey(imageUrl),
                                  child: Image.network(
                                    imageUrl,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _AvatarInitials(
                                      initials: initials,
                                      size: 72,
                                    ),
                                  ),
                                )
                              : _AvatarInitials(
                                  key: ValueKey(initials),
                                  initials: initials,
                                  size: 72,
                                ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: IgnorePointer(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isDark
                                      ? PlanoraTheme.darkSurface
                                      : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: isUploadingPicture
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.photo_camera_outlined,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : 'Planora User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      username.isNotEmpty ? '@$username' : '@username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _profileMutedColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canTap ? onChangePicture : null,
              icon: isUploadingPicture
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                isUploadingPicture ? 'Uploading picture...' : 'Change picture',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  final String initials;
  final double size;

  const _AvatarInitials({
    super.key,
    required this.initials,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.31,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _ProfileTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _EditProfileHint extends StatelessWidget {
  final bool isValid;
  final String text;

  const _EditProfileHint({required this.isValid, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = isValid ? PlanoraTheme.success : PlanoraTheme.error;

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ) ??
          TextStyle(color: color, fontWeight: FontWeight.w700),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              isValid ? Icons.check_circle_rounded : Icons.info_rounded,
              key: ValueKey(isValid),
              size: 15,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class ProfileInfoContent {
  const ProfileInfoContent._();

  static const String betaSupportEmail = 'planora.verify@gmail.com';

  static List<ProfileInfoSection>? sectionsForTitle(String title) {
    switch (title) {
      case 'Help & Support':
        return helpSupport;
      case 'Subscription':
        return subscription;
      case 'Billing & Invoices':
        return billingAndInvoices;
      case 'Email Preferences':
        return emailPreferences;
      case 'Notification Settings':
        return notificationSettings;
      case 'Privacy Policy':
        return privacyPolicy;
      case 'Terms of Service':
        return terms;
      default:
        return null;
    }
  }

  static const List<ProfileInfoSection> helpSupport = [
    ProfileInfoSection(
      title: 'Beta support',
      body:
          'Planora is currently in beta. Some features may still be incomplete, limited, or under active testing. If something does not work as expected, report the issue with enough detail so it can be reproduced and fixed.',
    ),
    ProfileInfoSection(
      title: 'What to include in a support request',
      body:
          'When reporting an issue, include your account email, username, the screen you were using, the exact action you tried, and the error message you saw.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For beta support, contact Planora support at planora.verify@gmail.com.',
    ),
  ];

  static const List<ProfileInfoSection> subscription = [
    ProfileInfoSection(
      title: 'Planora Beta Access',
      body:
          'Your account is currently using the standard Planora beta workspace experience. During beta, paid plans, upgrades, downgrades, billing, and invoices are not available in the mobile app.',
    ),
    ProfileInfoSection(
      title: 'Current plan',
      body: 'Plan: Beta Access\nPrice: Free during beta\nRenewal: Not applicable',
    ),
    ProfileInfoSection(
      title: 'Included in beta',
      body:
          'Projects and task management\nTeam collaboration\nInvitations and comments\nNotifications\nProfile and account settings\nAttachments, when enabled\nAI planning features, when available',
    ),
    ProfileInfoSection(
      title: 'Future subscription plans',
      body:
          'Paid plans may be added later for larger teams, advanced AI usage, additional storage, or workspace-level features.',
    ),
  ];

  static const List<ProfileInfoSection> billingAndInvoices = [
    ProfileInfoSection(
      title: 'Billing unavailable',
      body:
          'Billing and invoice history are not available in the beta mobile app yet.',
    ),
  ];

  static const List<ProfileInfoSection> emailPreferences = [
    ProfileInfoSection(
      title: 'Email preferences unavailable',
      body:
          'Email preference controls are not available in the beta mobile app yet. Notification delivery is managed by the current backend defaults.',
    ),
  ];

  static const List<ProfileInfoSection> notificationSettings = [
    ProfileInfoSection(
      title: 'Notification settings unavailable',
      body:
          'Per-channel notification controls are not exposed by the backend yet. In-app notifications continue to use the current default behavior.',
    ),
  ];

  static const List<ProfileInfoSection> privacyPolicy = [
    ProfileInfoSection(
      title: 'Account information',
      body:
          'Planora stores account details such as your name, username, email, profile picture, role, verification status, and account creation date so your workspace can function across devices.',
    ),
    ProfileInfoSection(
      title: 'Workspace data',
      body:
          'Planora stores projects, tasks, teams, invitations, comments, attachments, notifications, activity logs, AI planning requests, and related collaboration data needed to provide the service.',
    ),
    ProfileInfoSection(
      title: 'Profile pictures',
      body:
          'Profile pictures are uploaded to your Planora account and may be shown to you and other workspace members where your profile appears.',
    ),
    ProfileInfoSection(
      title: 'AI features',
      body:
          'When you use AI planning features, the task or project details you provide may be processed to generate schedules, plans, summaries, or suggestions.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For privacy questions, contact Planora support at planora.verify@gmail.com.',
    ),
  ];

  static const List<ProfileInfoSection> terms = [
    ProfileInfoSection(
      title: 'Beta software',
      body:
          'Planora is currently beta software. Features may change, be limited, or be temporarily unavailable while the app is being tested and improved.',
    ),
    ProfileInfoSection(
      title: 'Account responsibility',
      body:
          'You are responsible for keeping your login credentials secure and for the activity that happens under your account.',
    ),
    ProfileInfoSection(
      title: 'Acceptable use',
      body:
          'Do not misuse Planora, attempt unauthorized access, upload harmful content, or interfere with other users, workspaces, or backend services.',
    ),
    ProfileInfoSection(
      title: 'Uploads and profile content',
      body:
          'Only upload files and profile pictures that you have the right to use and that are appropriate for a project management workspace.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For terms or access questions, contact Planora support at planora.verify@gmail.com.',
    ),
  ];
}
