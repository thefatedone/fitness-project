// =============================================================================
// Onboarding wizard — 4-step registration flow
// =============================================================================
//
// Collects auth credentials PLUS full onboarding data (DOB, sex, body
// metrics, activity level, goal, dietary preferences, allergies) in one
// flow, then calls `POST /auth/register` immediately followed by
// `PUT /users/me` with the rest of the payload. Mirrors
// `nutrimind/src/app/(auth)/register/page.tsx` from the web app.
//
// Design choices:
//   * **State shape**: each step owns a `GlobalKey<FormState>` declared
//     on the wizard's State. The wizard holds one key per step and
//     passes it down; when the user taps "Next", the wizard calls
//     `key.currentState!.validate()`. Cross-field validators (e.g.
//     password match) read live values from sibling controllers at
//     validate-time.
//   * **Required selections that aren't TextFormFields** (date picker
//     rows, ChoiceChip groups, Sex dropdown) are wrapped in a
//     `FormField<T>` so they participate in the same
//     `currentState.validate()` flow. Their errorText is rendered
//     inline below the row.
//   * **Navigation**: a `PageView` with `NeverScrollableScrollPhysics`
//     driven by a `PageController`. Swipe-between-pages is disabled;
//     step transitions go strictly through the bottom buttons.
//   * **Data sharing**: an `OnboardingData` plain class is created
//     once in the wizard's State and passed down to each step. Steps
//     write into `data.<field>` on every keystroke (via `onChanged`)
//     so values persist across back-and-forward navigation.
//   * **No manual navigation on success**: `AuthProvider.register`
//     flips `status` to `authenticated` on success and `AuthGate`
//     auto-navigates to the home screen. The wizard MUST NOT push /
//     pop routes on success.
// =============================================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/gen/app_localizations_lookup.dart';
import '../../../widgets/glass/glass_card.dart';

import '../../profile/providers/profile_api.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/widgets/tag_input.dart';
import '../providers/auth_api.dart';
import '../providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Shared data holder
// ---------------------------------------------------------------------------

/// Mutable state that all four wizard steps read from and write to.
///
/// Plain class (no Provider, no ChangeNotifier) by design — every step
/// is co-located in this file, so direct field mutation is simpler than
/// a callback-per-field setter chain. Lives only as long as the wizard
/// route; once `AuthGate` takes over, the wizard unmounts and this
/// instance is GC'd.
class OnboardingData {
  // ---- step 1: credentials ----------------------------------------------------
  String fullName = '';
  String email = '';
  String password = '';
  String confirmPassword = '';

  // ---- step 2: personal info --------------------------------------------------
  DateTime? dateOfBirth;
  String? sex; // 'male' | 'female' | 'other'

  // ---- step 3: body & goal ---------------------------------------------------
  double? height; // cm
  double? currentWeight; // kg
  double? targetWeight; // kg

  /// Matches an `activityLevels` value (`'sedentary'`, `'lightly_active'`, …).
  String? activityLevel;

  /// Matches a `primaryGoals` value (`'lose_weight'`, `'gain_muscle'`, …).
  String? primaryGoal;

  /// kg/week; 0.25 → 1.0 in 4 stops. Defaults to 0.5 so the slider
  /// has a sensible resting position.
  double weightLossPace = 0.5;

  // ---- step 4: dietary & allergies ------------------------------------------
  ///
  /// Both lists are **ordered** (`List<String>`, not `Set`), matching
  /// the same convention the rest of the app uses after the tag-input
  /// upgrade. Insertion order is preserved on save + on round-trip.
  List<String> dietaryPrefs = <String>[];
  List<String> allergies = <String>[];
}

// ---------------------------------------------------------------------------
// Shared UI bits (used by all step bodies)
// ---------------------------------------------------------------------------

/// `yyyy-MM-dd` for sending to the backend. We don't reuse this for
/// on-screen display — each step inlines the format expression so the
/// display stays colocated with the row that owns it.
String _formatYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Widget _sectionTitle(BuildContext context, String text) => Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );

Widget _sectionSubtitle(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );

/// Inline error label rendered under a `FormField` when its validator
/// rejects. Keeps the chip-row / date-row cases visually consistent
/// with text-field errors.
Widget _fieldError(BuildContext context, String? message) {
  if (message == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6, left: 12),
    child: Text(
      message,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: 12,
      ),
    ),
  );
}

/// Numeric-field validator shared across every step that takes a
/// `double` from the user (height / current weight / target weight).
/// Accepts both `,` and `.` as a decimal separator — Russian
/// locales use `,`. Returns an empty string for an unparseable input
/// rather than throwing.
String? _numberValidator(BuildContext context, String? raw) {
  final v = raw ?? '';
  if (v.trim().isEmpty) return AppLocalizations.of(context).onboardingRequired;
  final n = num.tryParse(v.trim().replaceAll(',', '.'));
  if (n == null) return AppLocalizations.of(context).onboardingEnterNumber;
  if (n <= 0) return AppLocalizations.of(context).onboardingMustBePositive;
  return null;
}

/// `double?` parsed from a `TextEditingController`, with the
/// comma-tolerant same-parse semantics as [_numberValidator].
double? _parseNumber(String? v) {
  if (v == null) return null;
  final t = v.trim();
  if (t.isEmpty) return null;
  return num.tryParse(t.replaceAll(',', '.'))?.toDouble();
}

// ---------------------------------------------------------------------------
// Wizard root
// ---------------------------------------------------------------------------

/// Top-level onboarding wizard. Holds the cross-step state and
/// orchestrates per-step validation, page transitions, and the final
/// `register` + `updateProfile` two-step submission.
class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  /// Matches the regex already used in `register_screen.dart` so the
  /// two flows agree on what counts as a valid email.
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static const _totalSteps = 4;

  final _data = OnboardingData();

  int _currentStep = 0;

  /// Spinner-state for the final-step submit button.
  bool _isSubmitting = false;

  // One form key per step. Each step widget binds to its own key.
  // The wizard calls [key.currentState!.validate()] when the user
  // taps "Next"; the Form inside that step runs every field's
  // validator (including non-text-FormFields that opt in).
  final List<GlobalKey<FormState>> _stepFormKeys = List.generate(
    _totalSteps,
    (_) => GlobalKey<FormState>(),
  );

  late final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Programmatic page switch, used by the bottom Next / Back buttons.
  /// Avoids setting state inside the `onPageChanged` callback (which
  /// would loop).
  void _goToStep(int step) {
    if (step < 0 || step >= _totalSteps) return;
    setState(() => _currentStep = step);
    _pageController.jumpToPage(step);
  }

  void _onBack() {
    if (_currentStep > 0) _goToStep(_currentStep - 1);
  }

  Future<void> _onNext() async {
    // (1) Validate the current step's form. If any validator (text-
    // field, FormField<DateTime>, FormField<String> for chip groups)
    // fails, stay on the step and surface the inline error.
    final key = _stepFormKeys[_currentStep];
    final state = key.currentState;
    if (state != null && !state.validate()) return;

    // (2) Not the final step → just advance.
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
      return;
    }

    // (3) Final step — submit.
    setState(() => _isSubmitting = true);

    final authProvider = context.read<AuthProvider>();

    // 3a. Register first. If the email is already in use (or any
    //     other auth-side failure), kick the user back to step 1
    //     where the offending input lives rather than leaving them
    //     staring at a half-submitted "complete registration" button.
    final registerOk = await authProvider.register(
      email: _data.email,
      password: _data.password,
      fullName: _data.fullName,
    );
    if (!registerOk) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _goToStep(0);
      final msg = authProvider.errorMessageKey != null
              ? AppLocalizations.of(context).lookup(authProvider.errorMessageKey!) ?? authProvider.errorMessage ?? ''
              : authProvider.errorMessage ?? AppLocalizations.of(context).onboardingGenericError;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    // 3b. Registration succeeded — `AuthProvider.status` is now
    //     `authenticated`, so AuthGate's exhaustive switch will swap
    //     to `TrackerHomeScreen` the moment this widget rebuilds.
    //     We kick off the PUT `/users/me` here with the rest of the
    //     onboarding payload; even if the wizard unmounts before it
    //     finishes (best-case: AuthGate swapped us out), the auth
    //     state is already correct and the user lands on Home with
    //     empty targets, which they'll fill in later via Profile.
    try {
      final profileApi = ProfileApi();
      final profileFields = <String, dynamic>{
        if (_data.dateOfBirth != null)
          'date_of_birth': _formatYmd(_data.dateOfBirth!),
        if (_data.sex != null) 'sex': _data.sex,
        if (_data.height != null) 'height': _data.height,
        if (_data.currentWeight != null) 'current_weight': _data.currentWeight,
        if (_data.targetWeight != null) 'target_weight': _data.targetWeight,
        if (_data.activityLevel != null) 'activity_level': _data.activityLevel,
        if (_data.primaryGoal != null) 'primary_goal': _data.primaryGoal,
        'weight_loss_pace': _data.weightLossPace,
        // The dietary / allergies lists are optional in the backend,
        // but our PUT payload is "apply only fields with non-default
        // values" style, so an empty string here tells the backend
        // "clear these tags". That's the desired behaviour — a user
        // who doesn't fill them in step 4 ends up with no tags,
        // matching the auth-screen default.
        'dietary_preferences': _data.dietaryPrefs.join(','),
        'food_allergies': _data.allergies.join(','),
      };

      final updatedUser =
          await profileApi.updateProfile(profileFields);
      // Refresh the auth state with server-computed fields
      // (bmr / tdee / daily_cal_target) so the home screen
      // calorie / macro rings render with the user's real numbers
      // on first paint.
      authProvider.updateCurrentUser(updatedUser);
    } catch (e, st) {
      // Don't block on profile-update failure — registration
      // itself succeeded and `AuthGate` is already navigating. Log
      // and surface a non-blocking nudge instead.
      debugPrint('Onboarding profile-update failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).onboardingPartialSaveWarning,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    // Registration succeeded — whether or not the profile-update PUT
    // above also succeeded, `AuthProvider.status` is now `authenticated`
    // and the wizard has to *get out of the way* so the user actually
    // lands on the home screen.
    //
    // The plain "AuthGate handles it" pattern is enough when the
    // surface IS the base route (e.g. LoginScreen itself), because
    // AuthGate lives at `MaterialApp.home` and its rebuild is the only
    // thing on screen. The wizard was reached via `Navigator.push()` so
    // it sits ON TOP of the base route — AuthGate's rebuild swaps the
    // base content underneath, but the wizard covers the result.
    // `popUntil((r) => r.isFirst)` clears every route above the base
    // (the wizard, the login screen, anything else the user pushed
    // before) so AuthGate's now-authenticated branch becomes visible.
    //
    // We pop here rather than in the try block because the
    // profile-update failure branch needs the same destination — the
    // account exists, the user is authenticated, the home screen is
    // the right place for them, and any "fill in your profile later"
    // nudge is delivered via the SnackBar above.
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).onboardingFinish),
        // The default AppBar leading arrow lets the user back out of
        // the wizard entirely. Per-step "Back" navigation lives in
        // the bottom nav row.
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _ProgressStrip(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _BlurredStepPager(
                controller: _pageController,
                currentStep: _currentStep,
                onStepChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _CredentialsStep(
                    formKey: _stepFormKeys[0],
                    data: _data,
                    emailRegex: _emailRegex,
                  ),
                  _PersonalInfoStep(
                    formKey: _stepFormKeys[1],
                    data: _data,
                  ),
                  _BodyAndGoalStep(
                    formKey: _stepFormKeys[2],
                    data: _data,
                  ),
                  _DietaryStep(
                    formKey: _stepFormKeys[3],
                    data: _data,
                  ),
                ],
              ),
            ),
            _BottomNavBar(
              currentStep: _currentStep,
              isLastStep: isLastStep,
              isSubmitting: _isSubmitting,
              onBack: _onBack,
              onNext: _onNext,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress strip
// ---------------------------------------------------------------------------

/// Four-segment strip showing where the user is in the wizard.
///
/// Each segment fills with [ColorScheme.primary] when reached or passed,
/// greys out when ahead. Using solid filled segments (instead of
/// pip-style dots) reads better on mobile widths.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = theme.colorScheme.primary;
    final pending = theme.colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (var i = 0; i < totalSteps; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= currentStep ? reached : pending,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav row
// ---------------------------------------------------------------------------

/// Back / Next (or "Finish registration") buttons at the bottom of
/// the wizard. Same vertical rhythm as the rest of the app's forms
/// (12 px outer padding, 48 px minimum button height).
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentStep,
    required this.isLastStep,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
  });

  final int currentStep;
  final bool isLastStep;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentStep > 0;
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            // Leading TextButton — sizes to its intrinsic label width,
            // doesn't need Expanded/Flexible. A plain `TextButton` is
            // happy with the unbounded Row constraint because it asks
            // for the size of its content, not a fill.
            TextButton(
              onPressed: canGoBack && !isSubmitting ? onBack : null,
              child: Text(AppLocalizations.of(context).onboardingBack),
            ),
            const SizedBox(width: 16),
            // Trailing FilledButton.icon — was crashing with
            // "BoxConstraints forces an infinite width" because its
            // `minimumSize: Size.fromHeight(48)` leaves width=∞, and
            // the Row passes its unbounded width straight through. We
            // wrap it in `Expanded` so the Row gives it a finite width
            // and the button's `minimumSize.height=48` is the only
            // dimension the button has to honour.
            Expanded(
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : onNext,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : null,
                label: Text(
                  isLastStep ? AppLocalizations.of(context).onboardingFinish : AppLocalizations.of(context).onboardingNext,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Credentials
// ---------------------------------------------------------------------------

/// Step 1: collect name, email, password, confirm-password.
///
/// All four values mirror into [OnboardingData] on every keystroke via
/// `onChanged`. Each [TextFormField] has its own validator; the
/// cross-field "passwords match" check lives on the `confirmPassword`
/// validator (reads `_passwordCtrl.text` at validate time, so it sees
/// the live value whenever the wizard calls
/// `_formKey.currentState!.validate()`).
class _CredentialsStep extends StatefulWidget {
  const _CredentialsStep({
    required this.formKey,
    required this.data,
    required this.emailRegex,
  });

  final GlobalKey<FormState> formKey;
  final OnboardingData data;
  final RegExp emailRegex;

  @override
  State<_CredentialsStep> createState() => _CredentialsStepState();
}

class _CredentialsStepState extends State<_CredentialsStep> {
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-fill controllers from `data` on rebuild so navigating
    // back-and-forward preserves input. (Direct field comparison
    // avoids recursive updates if the controller text already
    // matches `data.<field>`.)
    if (_fullNameCtrl.text != widget.data.fullName) {
      _fullNameCtrl.text = widget.data.fullName;
    }
    if (_emailCtrl.text != widget.data.email) {
      _emailCtrl.text = widget.data.email;
    }
    if (_passwordCtrl.text != widget.data.password) {
      _passwordCtrl.text = widget.data.password;
    }
    if (_confirmCtrl.text != widget.data.confirmPassword) {
      _confirmCtrl.text = widget.data.confirmPassword;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, AppLocalizations.of(context).onboardingStep1Title),
            _sectionSubtitle(
              context,
              AppLocalizations.of(context).onboardingStep1Subtitle,
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _fullNameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (v) => widget.data.fullName = v.trim(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).authRegisterName,
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppLocalizations.of(context).authRegisterNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              onChanged: (v) => widget.data.email = v.trim(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).authEmailLabel,
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final trimmed = (v ?? '').trim();
                if (trimmed.isEmpty) return AppLocalizations.of(context).authEmailRequired;
                if (!widget.emailRegex.hasMatch(trimmed)) {
                  return AppLocalizations.of(context).authEmailInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              onChanged: (v) => widget.data.password = v,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).authPasswordLabel,
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
                helperText:
                    'Min. 8 characters, one uppercase letter, one digit',
              ),
              validator: (v) => validatePassword(v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onChanged: (v) => widget.data.confirmPassword = v,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).authResetConfirmPassword,
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final trimmed = v ?? '';
                if (trimmed.isEmpty) return AppLocalizations.of(context).authResetConfirmRequired;
                if (trimmed != _passwordCtrl.text) {
                  return AppLocalizations.of(context).authResetMismatch;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — Personal info
// ---------------------------------------------------------------------------

/// Step 2: date of birth (custom [FormField]) + sex
/// ([DropdownButtonFormField]).
///
/// Both required — wrapped in their respective FormField so the wizard's
/// `currentState.validate()` call surfaces inline errors under each row.
/// The date row in particular wouldn't fit [FormField] naturally if we
/// used a plain [InkWell]; wrapping it lets it participate in the
/// same validation flow as every other text-field-based step.
class _PersonalInfoStep extends StatefulWidget {
  const _PersonalInfoStep({required this.formKey, required this.data});

  final GlobalKey<FormState> formKey;
  final OnboardingData data;

  @override
  State<_PersonalInfoStep> createState() => _PersonalInfoStepState();
}

class _PersonalInfoStepState extends State<_PersonalInfoStep> {
  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = widget.data.dateOfBirth ??
        DateTime(now.year - 20, now.month, now.day);
    // Clamp the initial date into the picker range so the system
    // sheet doesn't open with an out-of-range default.
    final clampedInitial = initial.isAfter(_lastDate(now))
        ? _lastDate(now)
        : initial.isBefore(_firstDate(now))
            ? _firstDate(now)
            : initial;

    final picked = await showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: _firstDate(now),
      lastDate: _lastDate(now),
    );
    if (picked != null) {
      setState(() => widget.data.dateOfBirth = picked);
    }
  }

  static DateTime _firstDate(DateTime now) =>
      DateTime(now.year - 100);
  static DateTime _lastDate(DateTime now) =>
      DateTime(now.year - 13, now.month, now.day);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, AppLocalizations.of(context).onboardingStep2Title),
            _sectionSubtitle(context, AppLocalizations.of(context).onboardingStep2Subtitle),
            const SizedBox(height: 20),

            // Date picker — FormField<DateTime> wraps our InkWell +
            // InputDecorator so it participates in the standard form
            // validation flow. `state.didChange(picked)` triggers the
            // validator and re-renders the error label; we mirror the
            // value into `data.dateOfBirth` as well so back-and-forward
            // navigation sees the same selection.
            FormField<DateTime>(
              initialValue: data.dateOfBirth,
              validator: (v) {
                if (v == null) return AppLocalizations.of(context).onboardingBirthdayRequired;
                return null;
              },
              builder: (state) {
                final dob = data.dateOfBirth;
                return InkWell(
                  onTap: () async {
                    await _pickDate(context);
                    // Pull whatever the picker decided (might still
                    // be null if the user cancelled).
                    state.didChange(data.dateOfBirth);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).onboardingBirthday,
                      prefixIcon: const Icon(Icons.cake_outlined),
                      border: const OutlineInputBorder(),
                      errorText: state.errorText,
                    ),
                    child: Text(
                      dob == null
                          ? AppLocalizations.of(context).onboardingBirthdayNotSet
                          : '${dob.day.toString().padLeft(2, '0')}.'
                              '${dob.month.toString().padLeft(2, '0')}.'
                              '${dob.year}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: dob == null
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Sex — DropdownButtonFormField gives us built-in
            // FormField integration and the same inline error
            // presentation as a TextFormField. `onChanged` syncs
            // straight into `data.sex`.
            DropdownButtonFormField<String>(
              initialValue: data.sex,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).onboardingGender,
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'male', child: Text(AppLocalizations.of(context).onboardingGenderMale)),
                DropdownMenuItem(value: 'female', child: Text(AppLocalizations.of(context).onboardingGenderFemale)),
                DropdownMenuItem(value: 'other', child: Text(AppLocalizations.of(context).onboardingGenderOther)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => data.sex = v);
              },
              validator: (v) => v == null
                  ? AppLocalizations.of(context).onboardingGenderRequired
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Body metrics & goal
// ---------------------------------------------------------------------------

/// Step 3: three numeric fields + activity level chip group + primary
/// goal chip group + weight-loss-pace slider.
///
/// Every required selection is wrapped in a [FormField] so it
/// participates in the wizard's standard `currentState.validate()`
/// flow. _numberValidator and _parseNumber centralise the comma/dot
/// tolerance so future steps don't reimplement it.
class _BodyAndGoalStep extends StatefulWidget {
  const _BodyAndGoalStep({required this.formKey, required this.data});

  final GlobalKey<FormState> formKey;
  final OnboardingData data;

  @override
  State<_BodyAndGoalStep> createState() => _BodyAndGoalStepState();
}

class _BodyAndGoalStepState extends State<_BodyAndGoalStep> {
  // One controller per numeric field; mirrors what `_CredentialsStep`
  // does so the texture across steps is uniform.
  late final TextEditingController _heightCtrl;
  late final TextEditingController _currentWeightCtrl;
  late final TextEditingController _targetWeightCtrl;

  @override
  void initState() {
    super.initState();
    _heightCtrl = TextEditingController(
      text: widget.data.height?.toString() ?? '',
    );
    _currentWeightCtrl = TextEditingController(
      text: widget.data.currentWeight?.toString() ?? '',
    );
    _targetWeightCtrl = TextEditingController(
      text: widget.data.targetWeight?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _currentWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  Widget _numericField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ValueChanged<double?> onParsed,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: false),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: (v) => _numberValidator(context, v),
      onChanged: (v) => onParsed(_parseNumber(v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, AppLocalizations.of(context).onboardingStep3Title),
            _sectionSubtitle(
              context,
              AppLocalizations.of(context).onboardingStep3Subtitle,
            ),
            const SizedBox(height: 20),

            _numericField(
              controller: _heightCtrl,
              label: AppLocalizations.of(context).onboardingHeight,
              hint: 'e.g. 175',
              icon: Icons.straighten,
              onParsed: (v) => data.height = v,
            ),
            const SizedBox(height: 12),
            _numericField(
              controller: _currentWeightCtrl,
              label: AppLocalizations.of(context).onboardingCurrentWeight,
              hint: 'e.g. 70.5',
              icon: Icons.monitor_weight_outlined,
              onParsed: (v) => data.currentWeight = v,
            ),
            const SizedBox(height: 12),
            _numericField(
              controller: _targetWeightCtrl,
              label: AppLocalizations.of(context).onboardingTargetWeight,
              hint: 'e.g. 65',
              icon: Icons.flag_outlined,
              onParsed: (v) => data.targetWeight = v,
            ),
            const SizedBox(height: 16),

            // Activity level — FormField<String> wraps the chip group
            // so it integrates with the existing per-step validation
            // path. `state.didChange(value)` is called whenever a
            // chip is toggled; clear on deselection.
            FormField<String>(
              initialValue: data.activityLevel,
              validator: (v) {
                if (v == null) {
                  return AppLocalizations.of(context)
                      .onboardingActivityLevelRequired;
                }
                return null;
              },
              builder: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).onboardingActivityLevel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in activityLevels)
                        ChoiceChip(
                          label: Text(entry['label']!),
                          selected: data.activityLevel == entry['value'],
                          onSelected: (sel) {
                            final next = sel ? entry['value'] : null;
                            setState(() => data.activityLevel = next);
                            state.didChange(next);
                          },
                        ),
                    ],
                  ),
                  _fieldError(context, state.errorText),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Primary goal — same FormField pattern; emoji + label
            // widget mirrors the existing goal section in
            // profile_screen.dart.
            FormField<String>(
              initialValue: data.primaryGoal,
              validator: (v) {
                if (v == null) {
                  return AppLocalizations.of(context)
                      .onboardingPrimaryGoalRequired;
                }
                return null;
              },
              builder: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).onboardingPrimaryGoal,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in primaryGoals)
                        ChoiceChip(
                          selected: data.primaryGoal == entry['value'],
                          onSelected: (sel) {
                            final next = sel ? entry['value'] : null;
                            setState(() => data.primaryGoal = next);
                            state.didChange(next);
                          },
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (entry['emoji'] != null) ...[
                                Text(entry['emoji']!),
                                const SizedBox(width: 6),
                              ],
                              Text(entry['label']!),
                            ],
                          ),
                        ),
                    ],
                  ),
                  _fieldError(context, state.errorText),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Weight-loss pace — non-required, defaults to 0.5 so
            // the slider always has a sensible resting position. No
            // FormField wrapper needed; the slider's onChanged is
            // its own validation.
            Text(
              AppLocalizations.of(context).onboardingPaceLabel(
                data.weightLossPace.toStringAsFixed(2),
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: data.weightLossPace,
              min: 0.25,
              max: 1.0,
              divisions: 3,
              label: AppLocalizations.of(context).onboardingPaceChipLabel(
                data.weightLossPace.toStringAsFixed(2),
              ),
              onChanged: (v) => setState(() => data.weightLossPace = v),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4 — Dietary preferences + allergies
// ---------------------------------------------------------------------------

/// Step 4: free-text tag inputs for dietary preferences and allergies.
///
/// Both fields are OPTIONAL — the form has no validators, so even an
/// empty `Form` passes [Form.validate] trivially. No amber treatment
/// here; that's reserved for the ongoing-management Profile screen.
/// Keeps the wizard visually consistent through to the end.
class _DietaryStep extends StatefulWidget {
  const _DietaryStep({required this.formKey, required this.data});

  final GlobalKey<FormState> formKey;
  final OnboardingData data;

  @override
  State<_DietaryStep> createState() => _DietaryStepState();
}

class _DietaryStepState extends State<_DietaryStep> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;

    Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, AppLocalizations.of(context).onboardingStep4Title),
            _sectionSubtitle(
              context,
              AppLocalizations.of(context).onboardingStep4Subtitle,
            ),
            const SizedBox(height: 20),

            sectionLabel(AppLocalizations.of(context).onboardingDietaryPreferences),
            TagInputField(
              value: data.dietaryPrefs,
              onChanged: (v) => setState(() => data.dietaryPrefs = v),
              hintText: AppLocalizations.of(context).onboardingDietaryHint,
            ),
            const SizedBox(height: 20),

            sectionLabel(AppLocalizations.of(context).onboardingAllergies),
            TagInputField(
              value: data.allergies,
              onChanged: (v) => setState(() => data.allergies = v),
              hintText: AppLocalizations.of(context).onboardingAllergiesHint,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Blurred step pager
// ---------------------------------------------------------------------------

/// PageView wrapper that, while a step transition is in flight, blurs
/// the outgoing page (sigma 0 → 8) and resolves the incoming page
/// from the same blur back to sharp. The combined effect is a
/// "liquid glass" crossfade — the outgoing step's content dissolves
/// through a glassy haze while the next step solidifies behind it.
///
/// The widget wraps each child in a [GlassCard] automatically so
/// every step body shares the same Liquid Glass surface treatment
/// (without each step widget having to know about glass).
class _BlurredStepPager extends StatefulWidget {
  const _BlurredStepPager({
    required this.controller,
    required this.currentStep,
    required this.onStepChanged,
    required this.children,
  });

  final PageController controller;
  final int currentStep;
  final ValueChanged<int> onStepChanged;
  final List<Widget> children;

  @override
  State<_BlurredStepPager> createState() => _BlurredStepPagerState();
}

class _BlurredStepPagerState extends State<_BlurredStepPager> {
  double _page = 0;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPageEvent);
  }

  @override
  void didUpdateWidget(covariant _BlurredStepPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onPageEvent);
      widget.controller.addListener(_onPageEvent);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPageEvent);
    super.dispose();
  }

  void _onPageEvent() {
    final next =
        widget.controller.page ?? widget.controller.initialPage.toDouble();
    final animating = widget.controller.position.isScrollingNotifier.value;
    if (next != _page || animating != _animating) {
      setState(() {
        _page = next;
        _animating = animating;
      });
      final rounded = next.round();
      if (!animating && rounded != widget.currentStep) {
        widget.onStepChanged(rounded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: widget.controller,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _BlurredStep(
            // Blur intensity rises as this page moves AWAY from
            // the current page. The "outgoing" page carries the
            // high sigma; the "incoming" page is sharp.
            intensity: (_page - i).abs().clamp(0.0, 1.0),
            animating: _animating,
            child: widget.children[i],
          ),
      ],
    );
  }
}

/// Wraps a single onboarding step body in a [GlassCard] and applies
/// a transient [BackdropFilter] blur driven by [intensity]. When
/// [animating] is `false` (the step is the steady-state active
/// step), the blur is dropped entirely — the [BackdropFilter]
/// only runs during the crossfade window.
class _BlurredStep extends StatelessWidget {
  const _BlurredStep({
    required this.child,
    required this.intensity,
    required this.animating,
  });

  final Widget child;
  final double intensity;
  final bool animating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: animating && intensity > 0.05
              ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: intensity * 8,
                    sigmaY: intensity * 8,
                  ),
                  child: child,
                )
              : child,
        ),
      ),
    );
  }
}
