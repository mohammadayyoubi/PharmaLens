import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_text.dart';
import '../screens/analysis_screen.dart';
import '../services/health_profile_service.dart';
import '../theme/pharmalens_theme.dart';
import 'ai_notice.dart';
import 'family_member_dialog.dart';

const int _maximumImageBytes = 15 * 1024 * 1024;

bool _cameraAvailable(ImagePicker picker) {
  try {
    return picker.supportsImageSource(ImageSource.camera);
  } catch (_) {
    return false;
  }
}

/// Scans a prescription for one person.
///
/// With family members saved, or when [source] is not given, a sheet first
/// asks who the prescription is for (and offers to add someone) and how to
/// take the picture. The analysis then checks the medicines against that
/// person's allergies and health conditions, and saves the scan under them.
///
/// The analysis page is pushed on [navigator] (the current section's
/// navigator by default).
Future<void> startPrescriptionScan(BuildContext context, {ImageSource? source, NavigatorState? navigator}) async {
  final profiles = HealthProfileService();
  await profiles.load();
  if (!context.mounted) return;

  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final picker = ImagePicker();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final target = navigator ?? Navigator.of(context);
  void showError(String message) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  var profileId = profiles.active.id;
  var chosenSource = source;

  if (chosenSource == null || profiles.hasFamily) {
    final choice = await showModalBottomSheet<(String, ImageSource)>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ScanSheet(
        initialProfileId: profileId,
        source: chosenSource,
        cameraAvailable: _cameraAvailable(picker),
      ),
    );
    if (choice == null) return;
    profileId = choice.$1;
    chosenSource = choice.$2;
  }

  try {
    final picked = await picker.pickImage(
      source: chosenSource,
      // Gemini downsamples larger images anyway; a smaller upload is
      // noticeably faster on slow connections.
      imageQuality: 85,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (picked == null) return;

    final size = await picked.length();
    if (size <= 0) return showError(appText(isArabic).theSelectedImageIsEmptyPlease);
    if (size > _maximumImageBytes) return showError(appText(isArabic).theSelectedImageIsTooLarge);

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return showError(appText(isArabic).theSelectedImageCouldNotBe);

    await target.push(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisScreen(imagePath: picked.path, imageBytes: bytes, profileId: profileId),
      ),
    );
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Prescription image selection failed.\n$error');
      debugPrintStack(stackTrace: stackTrace);
    }
    showError(appText(isArabic).theImageCouldNotBeOpened);
  }
}

/// Who the prescription is for, and camera or gallery. Pops
/// `(profileId, source)`.
class _ScanSheet extends StatefulWidget {
  const _ScanSheet({required this.initialProfileId, required this.source, required this.cameraAvailable});

  final String initialProfileId;

  /// Already chosen on the home card; null asks for it here.
  final ImageSource? source;
  final bool cameraAvailable;

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  late String _profileId = widget.initialProfileId;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  Future<void> _addPerson() async {
    final person = await showAddFamilyMemberDialog(context, isArabic: _isArabic);
    if (person != null && mounted) setState(() => _profileId = person.id);
  }

  void _done(ImageSource source) => Navigator.of(context).pop((_profileId, source));

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(_isArabic);
    final service = HealthProfileService();

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final person = service.byId(_profileId) ?? service.active;

        final Widget buttons;
        if (widget.source != null) {
          buttons = FilledButton.icon(
            onPressed: () => _done(widget.source!),
            icon: Icon(widget.source == ImageSource.camera ? Icons.photo_camera_rounded : Icons.photo_library_rounded),
            label: Text(text.continueText),
          );
        } else {
          buttons = Row(
            children: [
              if (widget.cameraAvailable) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _done(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(text.takePhoto)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: widget.cameraAvailable
                    ? OutlinedButton.icon(
                        onPressed: () => _done(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(text.chooseFromGallery)),
                      )
                    : FilledButton.icon(
                        onPressed: () => _done(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(text.chooseFromGallery)),
                      ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(gradient: PharmaLensGradients.primary, borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.document_scanner_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text.scanAPrescription, style: TextStyle(color: palette.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          text.takeAPhotoOrChooseOneFromYourGallery,
                          style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                text.whoIsThisPrescriptionFor,
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final profile in service.profiles)
                    ChoiceChip(
                      avatar: Icon(profile.isOwner ? Icons.person_rounded : Icons.family_restroom_rounded, size: 18),
                      label: Text(profile.displayName(isArabic: _isArabic)),
                      selected: profile.id == person.id,
                      onSelected: (_) => setState(() => _profileId = profile.id),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(text.familyMember),
                    onPressed: _addPerson,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    person.hasHealthInfo ? Icons.health_and_safety_outlined : Icons.info_outline_rounded,
                    size: 17,
                    color: person.hasHealthInfo ? PharmaLensColors.teal : PharmaLensColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      !person.hasHealthInfo
                          ? text.noHealthInfoSavedForThisPerson
                          : person.isOwner
                              ? text.checkedAgainstYourHealthProfile
                              : text.checkedAgainstPersonHealthProfile(person.name),
                      style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              buttons,
              const SizedBox(height: 12),
              AiNotice(isArabic: _isArabic, compact: true),
            ],
          ),
        );
      },
    );
  }
}
