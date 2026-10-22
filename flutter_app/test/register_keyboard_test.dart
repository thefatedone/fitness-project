import 'package:flutter/services.dart';
import 'package:nutrimind/core/theme/app_theme.dart';
import 'package:nutrimind/features/auth/screens/onboarding_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nutrimind/features/auth/providers/auth_provider.dart';
import 'package:nutrimind/features/auth/screens/register_screen.dart';
import 'package:nutrimind/features/auth/screens/login_screen.dart';
import 'package:nutrimind/l10n/gen/app_localizations.dart';
import 'package:nutrimind/utils/accessibility_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Comfortaa')
      ..addFont(rootBundle.load('assets/fonts/Comfortaa-VariableFont.ttf'));
    await fonts.load();
  });
  for (final (name, screen, count) in [
    ('registration', const RegisterScreen(), 3),
    ('onboarding', const OnboardingWizardScreen(), 4),
    ('login', const LoginScreen(), 2),
  ]) {
    for (var field = 0; field < count; field++) {
      testWidgets(
        'iPhone $name field $field: blank touch hides keyboard; field taps retain editing',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.reset);
          final auth = AuthProvider();
          addTearDown(auth.dispose);
          await tester.pumpWidget(
            ReduceTransparencyScope(
              notifier: ReduceTransparencyNotifier.instance,
              child: ChangeNotifierProvider.value(
                value: auth,
                child: MaterialApp(
                  theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
                  locale: const Locale('en'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: name == 'onboarding' ? const LoginScreen() : screen,
                ),
              ),
            ),
          );
          if (name == 'onboarding') {
            final label = AppLocalizations.of(
              tester.element(find.byType(LoginScreen)),
            ).authNoAccountRegister;
            await tester.ensureVisible(find.text(label));
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
            expect(find.byType(OnboardingWizardScreen), findsOneWidget);
          }
          final fields = find.byType(TextFormField);
          EditableText editable(int index) =>
              tester.widget<EditableText>(find.byType(EditableText).at(index));
          await tester.ensureVisible(fields.at(field));
          await tester.enterText(fields.at(field), 'example');
          await tester.showKeyboard(fields.at(field));
          expect(tester.testTextInput.isVisible, isTrue);
          // Switching directly to another field must not trigger the outer tap.
          final next = (field + 1) % count;
          await tester.ensureVisible(fields.at(next));
          await tester.tap(fields.at(next));
          await tester.pump();
          expect(editable(next).focusNode.hasFocus, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);
          // Truly empty area beyond the centered card, within the route bounds.
          await tester.tapAt(const Offset(8, 125));
          await tester.pumpAndSettle();
          expect(tester.testTextInput.isVisible, isFalse);
          expect(editable(next).focusNode.hasFocus, isFalse);
          expect(editable(field).controller.text, 'example');
          await tester.ensureVisible(fields.at(field));
          await tester.tap(fields.at(field));
          await tester.pump();
          expect(editable(field).focusNode.hasFocus, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
