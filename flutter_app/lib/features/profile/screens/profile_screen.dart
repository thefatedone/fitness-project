// =============================================================================
// NATIVE CONFIGURATION (must be added manually to native files — Dart only)
// =============================================================================
//
// iOS — ios/Runner/Info.plist, add these keys inside the top-level <dict>:
//
//     <key>NSCameraUsageDescription</key>
//     <string>Used to take a profile picture.</string>
//     <key>NSPhotoLibraryUsageDescription</key>
//     <string>Used to pick a profile picture from your photo library.</string>
//     <key>NSPhotoLibraryAddUsageDescription</key>
//     <string>Used to save the cropped profile picture.</string>
//
// Android — android/app/src/main/AndroidManifest.xml, add these inside
// the top-level <manifest>, BEFORE the <application> tag:
//
//     <uses-permission android:name="android.permission.CAMERA"/>
//     <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
//         android:maxSdkVersion="32"/>
//     <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
//
// image_cropper additionally requires its UCropActivity to be declared
// (skip if you've already added it via the package's README):
//
//     <activity
//         android:name="com.yalantis.ucrop.UCropActivity"
//         android:screenOrientation="portrait"
//         android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
//
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/tag_input.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tracker/screens/weight_history_screen.dart';
import '../providers/profile_provider.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';

/// Profile view/edit screen.
///
/// Single responsibility: render the current user as a long form,
/// track field-level edits in local controllers / lists, and on Save
/// dispatch a [ProfileProvider.saveProfile] patch map carrying *only*
/// fields that actually changed (per the PUT-as-PATCH contract).
///
/// Dietary preferences and allergies are free-text `TagInputField`s
/// (matching the web tag-input component); everything else is a stock
/// Material text / dropdown / slider / date picker.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// Approximate upper bound on the base64 length we let through to the
/// backend. The `/users/me/photo` route caps decoded payloads at 5 MB
/// (4/3 inflation factor on encode ⇒ ~6.67 MB base64); we round up
/// slightly so the heuristic fires a touch earlier than the server's
/// own 400, saving the user a guaranteed-failing round-trip.
const int _maxBase64Chars = 6_900_000;

class _ProfileScreenState extends State<ProfileScreen> {
  // ---- controllers (initialised from AuthProvider.currentUser) --------------

  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _currentWeightCtrl;
  late final TextEditingController _targetWeightCtrl;

  // ---- choice fields -------------------------------------------------------

  DateTime? _dateOfBirth;
  String? _sex; // 'male' | 'female'
  String? _primaryGoal; // primaryGoals 'value'
  String? _activityLevel; // activityLevels 'value'

  // ---- range --------------------------------------------------------------

  double _weightLossPace = 0.5; // kg/week; init from user below
  final int _weightLossPaceDivisions = 3; // 0.25 → 1.0 in 4 stops

  // ---- free-text tag lists --------------------------------------------------
  //
  // Insertion order preserved (NOT alphabetical). The chip lists in
  // step 3 used `Set<String>` which dropped order; step 4 moved to
  // List<String>` so the saved comma-separated string matches the user's
  // edit order exactly.

  List<String> _dietaryPrefs = <String>[];
  List<String> _allergies = <String>[];

  // Captured from the previous build so we show each error exactly once
  // via post-frame, then `clearError()` it so a rebuild doesn't re-fire
  // the same SnackBar.
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    // The screen is only reachable when authenticated, so currentUser
    // is guaranteed non-null per the design contract. If it ever is
    // null, we degrade gracefully below by rendering empty form fields.
    final u = context.read<AuthProvider>().currentUser;

    _fullNameCtrl = TextEditingController(text: u?.fullName ?? '');
    _heightCtrl = TextEditingController(text: _fmtDouble(u?.height));
    _currentWeightCtrl =
        TextEditingController(text: _fmtDouble(u?.currentWeight));
    _targetWeightCtrl =
        TextEditingController(text: _fmtDouble(u?.targetWeight));
    _dateOfBirth = u?.dateOfBirth;
    _sex = u?.sex;
    _primaryGoal = u?.primaryGoal;
    _activityLevel = u?.activityLevel;
    _weightLossPace = u?.weightLossPace ?? 0.5;
    _dietaryPrefs = _parseTagsOrdered(u?.dietaryPreferences);
    _allergies = _parseTagsOrdered(u?.foodAllergies);

    // Trigger a rebuild on every keystroke in the body-metric fields
    // so the live BMI display stays accurate while the user types.
    // Cheap (no provider round-trip — pure local arithmetic).
    _heightCtrl.addListener(_recompute);
    _currentWeightCtrl.addListener(_recompute);
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _heightCtrl.dispose();
    _currentWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  void _recompute() => setState(() {});

  // ---- helpers -------------------------------------------------------------

  /// Splits a backend CSV (`"Vegetarian, Vegan"` or `null`) into an
  /// ordered, case-insensitively-deduped list. Empty / null yields
  /// `[]`. Insertion order matches the wire format — important for the
  /// display, since two equivalent strings like "Milk" + "milk" would
  /// be one chip on screen but two on the wire (and the Save diff
  /// would flag a no-op change as a real edit if we naively sorted).
  static List<String> _parseTagsOrdered(String? csv) {
    if (csv == null || csv.trim().isEmpty) return <String>[];
    final out = <String>[];
    final seenLower = <String>{};
    for (final raw in csv.split(',')) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      final lower = tag.toLowerCase();
      if (seenLower.contains(lower)) continue;
      seenLower.add(lower);
      out.add(tag);
    }
    return out;
  }

  /// Formats a double for display inside a TextField. Empty string
  /// rather than `"0"` for `null` so the user sees a blank field
  /// instead of having to clear a `0`.
  static String _fmtDouble(double? v) {
    if (v == null) return '';
    final s = v.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  /// Parses a decimal-accepting field. Comma OR dot is fine (Russian
  /// locales use `,`). Returns `null` for empty / unparseable input.
  static double? _parseDouble(String? v) {
    if (v == null) return null;
    final t = v.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  /// `yyyy-MM-dd` for sending to the backend. We don't reuse this for
  /// on-screen display — the BasicInfo card inlines the formatting
  /// itself rather than going through a shared helper, to keep the
  /// display expression colocated with the `InputDecorator` it styles.
  static String _formatYmdForBackend(DateTime d) =>
      '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Resolves the relative `profile_photo` path the backend returns
  /// (`"/uploads/abc.jpg"`) against the API host the client was
  /// compiled against. Strips the `/api/v\d+` suffix from the base
  /// URL so the photo URL is rooted at the host (e.g. `http://localhost:8000`).
  String? _fullPhotoUrl(String? relativePath) {
    if (relativePath == null) return null;
    // If the server ever hands us a fully-qualified URL, use it as-is.
    if (relativePath.startsWith('http://') ||
        relativePath.startsWith('https://')) {
      return relativePath;
    }
    final base = AppConfig.apiBaseUrl
        .replaceFirst(RegExp(r'/api/v\d+$'), '');
    final path = relativePath.startsWith('/')
        ? relativePath
        : '/$relativePath';
    return '$base$path';
  }

  /// Live BMI = weight / (height/100)^2 in metric units. `null` while
  /// either field is missing or non-positive — the screen renders a
  /// neutral "—" placeholder rather than `Infinity` / `0`.
  double? _bmi() {
    final h = _parseDouble(_heightCtrl.text);
    final w = _parseDouble(_currentWeightCtrl.text);
    if (h == null || h <= 0 || w == null) return null;
    final hm = h / 100;
    return w / (hm * hm);
  }

  ({String label, Color color}) _bmiCategory(double bmi) {
    if (bmi < 18.5) {
      return (label: 'Недостаточный вес', color: const Color(0xFF3B82F6));
    }
    if (bmi < 25) {
      return (label: 'Норма', color: const Color(0xFF22C55E));
    }
    if (bmi < 30) {
      return (label: 'Избыточный вес', color: const Color(0xFFF97316));
    }
    return (label: 'Ожирение', color: const Color(0xFFEF4444));
  }

  // ---- date picker ----------------------------------------------------------

  Future<void> _pickDate() async {
    final initial = _dateOfBirth ??
        DateTime.now().subtract(const Duration(days: 365 * 25));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  // ---- photo pick → crop → upload -----------------------------------------

  /// Top-level entry: opens a modal bottom sheet letting the user pick
  /// camera or gallery. Mirrors the meal-type picker pattern from
  /// `tracker_home_screen.dart` and the cancel-vs-error semantics from
  /// `photo_food_screen.dart`.
  Future<void> _onCameraTap() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Откуда взять фото?',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Сделать фото'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickCropUpload(source);
  }

  /// Runs the picker → cropper → upload pipeline for a single image
  /// source. Each step has explicit cancellation / failure handling so
  /// no one path can leak an unhelpful error to the user.
  Future<void> _pickCropUpload(ImageSource source) async {
    // (1) Pick — silent on cancel, SnackBar with a Russian hint on a
    // real exception (mirrors photo_food_screen.dart's picker block).
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } catch (_) {
      if (!mounted) return;
      _showPickerError(source);
      return;
    }
    if (picked == null || !mounted) return;

    // (2) Crop — `null` result means the user cancelled the cropper UI;
    // expected behaviour, no SnackBar.
    //
    // We pin the output to a 1:1 square at three levels so the user
    // can't drag the bounding rectangle into an oval:
    //   * top-level `aspectRatio: 1:1` — sets the initial crop bounds
    //   * `cropStyle: CropStyle.circle` — the slider UI is round, not a
    //     draggable rectangle-and-corners
    //   * per-platform `lockAspectRatio: true` (Android) /
    //     `aspectRatioLockEnabled: true` (iOS) plus an `aspectRatioPresets`
    //     list of length one, so even when the user manipulates the
    //     ratio picker the only choice is "square".
    final CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Обрезать фото',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Обрезать фото',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
          ),
        ],
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Не удалось обрезать фото. Попробуй ещё раз.');
      return;
    }
    if (cropped == null || !mounted) return;

    // (3) Encode + client-side size guard — saves the user a
    // guaranteed-to-fail upload if the cropped JPEG is somehow huge
    // (the picker + cropper at quality 85 normally produce <500 KB
    // files, but a 12-MP original could push past the 5 MB ceiling
    // before our compress step catches up).
    if (!mounted) return;
    final File croppedFile = File(cropped.path);
    final List<int> bytes;
    try {
      bytes = await croppedFile.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Не удалось прочитать обрезанное фото.');
      return;
    }
    if (!mounted) return;
    final String encoded = base64Encode(bytes);
    if (encoded.length > _maxBase64Chars) {
      _showSnack('Фото слишком большое, попробуй другое');
      return;
    }

    // (4) Upload — the provider pushes the resulting profilePhoto into
    // AuthProvider, which re-runs this screen's build and refreshes the
    // CircleAvatar via the same context.watch the user already runs.
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final profile = context.read<ProfileProvider>();
    final ok = await profile.uploadAndSavePhoto(
      authProvider: auth,
      base64Image: encoded,
    );
    if (!mounted) return;

    if (ok) {
      _showSnack('Фото обновлено');
    } else if (profile.errorMessage != null) {
      _showSnack(profile.errorMessage!);
    }
  }

  void _showPickerError(ImageSource source) {
    final hint = source == ImageSource.camera
        ? 'Не удалось открыть камеру. Попробуй выбрать фото из галереи.'
        : 'Не удалось открыть галерею.';
    _showSnack(hint);
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  // ---- save ----------------------------------------------------------------

  Future<void> _onSave() async {
    final u = context.read<AuthProvider>().currentUser;
    final auth = context.read<AuthProvider>();
    final profile = context.read<ProfileProvider>();

    final fields = <String, dynamic>{};

    // text fields — diff against currentUser so we don't push noise
    final name = _fullNameCtrl.text.trim();
    if (name != (u?.fullName ?? '')) fields['full_name'] = name;

    final dob = _dateOfBirth;
    if (dob != null) fields['date_of_birth'] = _formatYmdForBackend(dob);

    final sex = _sex;
    if (sex != null && sex != u?.sex) fields['sex'] = sex;

    final h = _parseDouble(_heightCtrl.text);
    if (h != null && h != u?.height) fields['height'] = h;

    final cw = _parseDouble(_currentWeightCtrl.text);
    if (cw != null && cw != u?.currentWeight) fields['current_weight'] = cw;

    final tw = _parseDouble(_targetWeightCtrl.text);
    if (tw != null && tw != u?.targetWeight) fields['target_weight'] = tw;

    final al = _activityLevel;
    if (al != null && al != u?.activityLevel) fields['activity_level'] = al;

    final pg = _primaryGoal;
    if (pg != null && pg != u?.primaryGoal) fields['primary_goal'] = pg;

    // Tags — ordered list joined back into the backend's CSV shape.
    final prefsCsv = _dietaryPrefs.join(',');
    if (prefsCsv != (u?.dietaryPreferences ?? '')) {
      fields['dietary_preferences'] = prefsCsv;
    }
    final algsCsv = _allergies.join(',');
    if (algsCsv != (u?.foodAllergies ?? '')) {
      fields['food_allergies'] = algsCsv;
    }

    if (_weightLossPace != (u?.weightLossPace ?? 0.5)) {
      fields['weight_loss_pace'] = _weightLossPace;
    }

    final ok = await profile.saveProfile(
      authProvider: auth,
      fields: fields,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Профиль обновлён'
                : (profile.errorMessage ?? 'Не удалось сохранить.'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Renders a one-shot SnackBar for each new error message, then
  /// clears the provider's flag so a rebuild doesn't re-fire it.
  void _postBuildEffects({String? errorMessage}) {
    if (errorMessage == null || errorMessage == _lastShownError) return;
    _lastShownError = errorMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(errorMessage), behavior: SnackBarBehavior.floating),
        );
      context.read<ProfileProvider>().clearError();
    });
  }

  // ---- navigation to other profile screens -------------------------------

  Future<void> _openChangePassword() async {
    // No reload needed on return — the change-password screen mutates
    // the user's auth state on the backend; if the user comes back to
    // here, the existing context.watch on AuthProvider/ProfileProvider
    // is enough.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _openDeleteAccount() async {
    // The delete-account screen handles its own auth-state teardown on
    // success (logout + popUntil to base route), so we just push and
    // don't need any return-state plumbing here.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
    );
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<ProfileProvider>();
    // watch() on AuthProvider is what keeps the avatar up-to-date
    // after `uploadAndSavePhoto` pushes the new URL into `currentUser`.
    final u = context.watch<AuthProvider>().currentUser;

    _postBuildEffects(errorMessage: profile.errorMessage);

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _PhotoSection(
              photoUrl: _fullPhotoUrl(u?.profilePhoto),
              isLoading: profile.isUploadingPhoto,
              onCameraTap: _onCameraTap,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _BasicInfoCard(
              fullNameCtrl: _fullNameCtrl,
              dateOfBirth: _dateOfBirth,
              onPickDate: _pickDate,
              sex: _sex,
              onSexChanged: (v) => setState(() => _sex = v),
              theme: theme,
            ),
            const SizedBox(height: 12),
            _BodyMetricsCard(
              heightCtrl: _heightCtrl,
              currentWeightCtrl: _currentWeightCtrl,
              targetWeightCtrl: _targetWeightCtrl,
              bmi: _bmi(),
              bmiCategory: _bmiCategory,
              theme: theme,
              onNavigateToHistory: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WeightHistoryScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _GoalActivityCard(
              primaryGoal: _primaryGoal,
              activityLevel: _activityLevel,
              weightLossPace: _weightLossPace,
              paceDivisions: _weightLossPaceDivisions,
              onGoalChanged: (v) => setState(() => _primaryGoal = v),
              onActivityChanged: (v) => setState(() => _activityLevel = v),
              onPaceChanged: (v) => setState(() => _weightLossPace = v),
              theme: theme,
            ),
            const SizedBox(height: 12),

            // ----- Free-text tag lists ------------------------------------
            //
            // The previous FilterChip-based cards offered only a curated
            // short list. The web version lets the user type any custom
            // tag, so we use the shared `TagInputField` here. Insertion
            // order is preserved (NOT alphabetical), case is preserved
            // on first entry, and duplicates collapse via case-
            // insensitive comparison — all handled inside TagInputField.
            //
            // The lists ARE disabled while a save is in flight so the
            // user can't edit tags mid-PUT (which would either lose
            // the edit or, worse, race the in-flight request).

            _PreferencesCard(
              value: _dietaryPrefs,
              onChanged: (v) => setState(() => _dietaryPrefs = v),
              theme: theme,
              disabled: profile.isSaving,
            ),
            const SizedBox(height: 12),
            _AllergiesCard(
              value: _allergies,
              onChanged: (v) => setState(() => _allergies = v),
              theme: theme,
              disabled: profile.isSaving,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: profile.isSaving ? null : _onSave,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: profile.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Сохранить изменения'),
            ),
            const SizedBox(height: 12),

            // Settings-style entry point. Below the save button so
            // the form's primary action stays at the visual centre of
            // the page; "Сменить пароль" is an out-of-form action and
            // reads as settings, not data entry.
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                leading: Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: const Text(
                  'Сменить пароль',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onTap: _openChangePassword,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Danger-zone entry point. Visually separated from the
            // routine "change password" row above with a gap and an
            // error-tinted card so it's impossible to tap by accident
            // without noticing the visual weight change. Still inside
            // the same ListView / single Card surface so it lives in
            // the same logical group.
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                leading: Icon(
                  Icons.delete_forever,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Удалить аккаунт',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.error,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.error,
                ),
                onTap: _openDeleteAccount,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Section: photo
// ============================================================================

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photoUrl,
    required this.isLoading,
    required this.onCameraTap,
    required this.theme,
  });

  final String? photoUrl;
  final bool isLoading;
  final VoidCallback onCameraTap;
  final ThemeData theme;

  /// Build the avatar node — a circle containing either the loaded
  /// network image or a person-outline placeholder. Kept separate
  /// from the loading-overlay wrapper so the overlay can layer cleanly
  /// on top of whatever is rendered inside.
  Widget _avatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Placeholder(theme: theme),
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return _Placeholder(theme: theme);
              },
            )
          : _Placeholder(theme: theme),
    );
  }

  /// Loading overlay — dark scrim + spinner, sized to the avatar.
  Widget _loadingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.55),
        ),
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _avatar(),
            if (isLoading) _loadingOverlay(),
          ],
        ),
      ).withCameraButton(onCameraTap: onCameraTap, theme: theme),
    );
  }
}

/// Small helper extension to position the camera FAB at the bottom-right
/// of the avatar without disturbing the photo node's internal loading
/// overlay layout. Keeps the widget tree flat and easy to read.
extension on Widget {
  Widget withCameraButton({
    required VoidCallback onCameraTap,
    required ThemeData theme,
  }) {
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        this,
        Positioned(
          right: -2,
          bottom: -2,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Material(
              color: theme.colorScheme.primaryContainer,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onCameraTap,
                child: Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.person_outline,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ============================================================================
// Section: basic info
// ============================================================================

class _BasicInfoCard extends StatelessWidget {
  const _BasicInfoCard({
    required this.fullNameCtrl,
    required this.dateOfBirth,
    required this.onPickDate,
    required this.sex,
    required this.onSexChanged,
    required this.theme,
  });

  final TextEditingController fullNameCtrl;
  final DateTime? dateOfBirth;
  final VoidCallback onPickDate;
  final String? sex;
  final ValueChanged<String?> onSexChanged;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Основное',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: fullNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата рождения',
                  prefixIcon: Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  dateOfBirth == null
                      ? 'Не указана'
                      : '${dateOfBirth!.day.toString().padLeft(2, '0')}.'
                          '${dateOfBirth!.month.toString().padLeft(2, '0')}.'
                          '${dateOfBirth!.year}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: dateOfBirth == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: sex,
              decoration: const InputDecoration(
                labelText: 'Пол',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(value: 'male', child: Text('Мужской')),
                DropdownMenuItem<String>(value: 'female', child: Text('Женский')),
              ],
              onChanged: onSexChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Section: body metrics
// ============================================================================

class _BodyMetricsCard extends StatelessWidget {
  const _BodyMetricsCard({
    required this.heightCtrl,
    required this.currentWeightCtrl,
    required this.targetWeightCtrl,
    required this.bmi,
    required this.bmiCategory,
    required this.theme,
    required this.onNavigateToHistory,
  });

  final TextEditingController heightCtrl;
  final TextEditingController currentWeightCtrl;
  final TextEditingController targetWeightCtrl;
  final double? bmi;
  final ({String label, Color color}) Function(double bmi) bmiCategory;
  final ThemeData theme;
  final VoidCallback onNavigateToHistory;

  static String? _requiredNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Заполни';
    final n = double.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return 'Введи число';
    if (n <= 0) return 'Должно быть > 0';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasBmi = bmi != null;
    final cat = hasBmi ? bmiCategory(bmi!) : null;

    Widget metricField(TextEditingController c, String label, String hint) {
      return TextFormField(
        controller: c,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: const Icon(Icons.straighten),
          border: const OutlineInputBorder(),
        ),
        validator: (v) => _requiredNumber(v),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Параметры тела',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            metricField(heightCtrl, 'Рост, см', 'например, 175'),
            const SizedBox(height: 12),
            metricField(currentWeightCtrl, 'Текущий вес, кг', 'например, 70.5'),
            const SizedBox(height: 12),
            metricField(targetWeightCtrl, 'Целевой вес, кг', 'например, 65'),
            const SizedBox(height: 16),

            // BMI display — recomputed on every rebuild because
            // _heightCtrl / _currentWeightCtrl listeners trigger
            // setState when the user types.
            if (hasBmi && cat != null) ...[
              Row(
                children: [
                  Icon(Icons.monitor_weight_outlined,
                      color: cat.color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'ИМТ: ${cat.label}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cat.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    bmi!.toStringAsFixed(1),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            InkWell(
              onTap: onNavigateToHistory,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.timeline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Посмотреть историю веса',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Section: goal & activity
// ============================================================================

class _GoalActivityCard extends StatelessWidget {
  const _GoalActivityCard({
    required this.primaryGoal,
    required this.activityLevel,
    required this.weightLossPace,
    required this.paceDivisions,
    required this.onGoalChanged,
    required this.onActivityChanged,
    required this.onPaceChanged,
    required this.theme,
  });

  final String? primaryGoal;
  final String? activityLevel;
  final double weightLossPace;
  final int paceDivisions;
  final ValueChanged<String?> onGoalChanged;
  final ValueChanged<String?> onActivityChanged;
  final ValueChanged<double> onPaceChanged;
  final ThemeData theme;

  String _formatPace(double v) {
    // Two decimals without trailing zeros feels noisy for the snap
    // values 0.25/0.5/0.75/1.0 — switch to one decimal for a
    // smoother slider experience.
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  Widget _goalChip(Map<String, String> entry) {
    final value = entry['value']!;
    final label = entry['label']!;
    final emoji = entry['emoji'];
    return ChoiceChip(
      selected: primaryGoal == value,
      onSelected: (selected) => onGoalChanged(selected ? value : null),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }

  Widget _activityChip(Map<String, String> entry) {
    final value = entry['value']!;
    final label = entry['label']!;
    return ChoiceChip(
      selected: activityLevel == value,
      onSelected: (selected) => onActivityChanged(selected ? value : null),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Цель и активность',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Главная цель',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in primaryGoals) _goalChip(entry),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Уровень активности',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in activityLevels) _activityChip(entry),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Темп похудения: ${_formatPace(weightLossPace)} кг/неделю',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: weightLossPace,
              min: 0.25,
              max: 1.0,
              divisions: paceDivisions,
              label: '${_formatPace(weightLossPace)} кг/нед.',
              onChanged: onPaceChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Section: dietary preferences — FREE-TEXT tag list
// ============================================================================

/// Wraps the free-text `TagInputField` in the same card chrome the
/// other sections use. The chip-list contents come from
/// `_dietaryPrefs` in the parent, so all state lives in one place.
class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.value,
    required this.onChanged,
    required this.theme,
    required this.disabled,
  });

  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final ThemeData theme;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Диетические предпочтения',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TagInputField(
              value: value,
              onChanged: onChanged,
              disabled: disabled,
              hintText: 'Например, вегетарианец…',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Section: allergies — FREE-TEXT tag list, amber-accented for visibility
// ============================================================================

/// Same as `_PreferencesCard` but with the amber-tinted chrome that
/// signals "this drives safety elsewhere in the app" (the AI photo-
/// recogniser reads this list to flag allergen conflicts). Only the
/// inner input mechanism changes between step 3 and step 4; the
/// chrome stays put.
class _AllergiesCard extends StatelessWidget {
  const _AllergiesCard({
    required this.value,
    required this.onChanged,
    required this.theme,
    required this.disabled,
  });

  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final ThemeData theme;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      // Subtle amber border so the allergies section reads as
      // "important — this drives safety elsewhere" without screaming.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFFCD34D).withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 18,
                  color: const Color(0xFFB45309), // amber-700
                ),
                const SizedBox(width: 8),
                Text(
                  'Аллергии и непереносимости',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Используется AI-распознаванием фото для предупреждений о конфликтах.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TagInputField(
              value: value,
              onChanged: onChanged,
              disabled: disabled,
              hintText: 'Например, орехи…',
            ),
          ],
        ),
      ),
    );
  }
}
