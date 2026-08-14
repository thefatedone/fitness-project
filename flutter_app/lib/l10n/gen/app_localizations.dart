import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ka.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ka'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'NutriMind'**
  String get appName;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonYesDelete.
  ///
  /// In en, this message translates to:
  /// **'Yes, delete'**
  String get commonYesDelete;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please check your connection and try again.'**
  String get commonError;

  /// No description provided for @commonErrorShort.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get commonErrorShort;

  /// No description provided for @commonErrorWithRetry.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get commonErrorWithRetry;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeDescriptionLight.
  ///
  /// In en, this message translates to:
  /// **'Always use the light theme.'**
  String get themeDescriptionLight;

  /// No description provided for @themeDescriptionDark.
  ///
  /// In en, this message translates to:
  /// **'Always use the dark theme.'**
  String get themeDescriptionDark;

  /// No description provided for @themeDescriptionSystem.
  ///
  /// In en, this message translates to:
  /// **'Theme follows your system setting.'**
  String get themeDescriptionSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGeorgian.
  ///
  /// In en, this message translates to:
  /// **'ქართული'**
  String get languageGeorgian;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionLabel;

  /// No description provided for @languageFieldTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get languageFieldTheme;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'NutriMind'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authLoginSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a valid email'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Min. 8 characters, one uppercase letter, one digit'**
  String get authPasswordHelper;

  /// No description provided for @authLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLoginButton;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authNoAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get authNoAccountRegister;

  /// No description provided for @authServerDebugLink.
  ///
  /// In en, this message translates to:
  /// **'Server settings (debug)'**
  String get authServerDebugLink;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired, please log in again.'**
  String get authSessionExpired;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authRegisterName;

  /// No description provided for @authRegisterNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authRegisterNameRequired;

  /// No description provided for @authRegisterPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authRegisterPassword;

  /// No description provided for @authRegisterCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authRegisterCreate;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authForgotTitle;

  /// No description provided for @authForgotInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the email associated with your account — we\'ll send a code to reset your password.'**
  String get authForgotInstructions;

  /// No description provided for @authForgotSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authForgotSendCode;

  /// No description provided for @authCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get authCodeTitle;

  /// No description provided for @authCodeInstructions.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {email}'**
  String authCodeInstructions(String email);

  /// No description provided for @authCodeField.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get authCodeField;

  /// No description provided for @authCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Code must be 6 digits'**
  String get authCodeRequired;

  /// No description provided for @authCodeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get authCodeConfirm;

  /// No description provided for @authCodeResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authCodeResend;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authResetTitle;

  /// No description provided for @authResetInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password for {email}'**
  String authResetInstructions(String email);

  /// No description provided for @authResetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authResetNewPassword;

  /// No description provided for @authResetConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authResetConfirmPassword;

  /// No description provided for @authResetConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get authResetConfirmRequired;

  /// No description provided for @authResetMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get authResetMismatch;

  /// No description provided for @authResetSave.
  ///
  /// In en, this message translates to:
  /// **'Save new password'**
  String get authResetSave;

  /// No description provided for @authResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed. You can now log in.'**
  String get authResetSuccess;

  /// No description provided for @authEmailVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get authEmailVerifyTitle;

  /// No description provided for @authEmailVerifyInstructions.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a verification code to {email}'**
  String authEmailVerifyInstructions(String email);

  /// No description provided for @authEmailVerifyEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from the email'**
  String get authEmailVerifyEnterCode;

  /// No description provided for @authEmailVerifySendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authEmailVerifySendCode;

  /// No description provided for @authEmailVerifyResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authEmailVerifyResend;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authPasswordMinLength;

  /// No description provided for @authPasswordNeedUpper.
  ///
  /// In en, this message translates to:
  /// **'First letter of the password must be uppercase'**
  String get authPasswordNeedUpper;

  /// No description provided for @authPasswordNeedDigit.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one digit'**
  String get authPasswordNeedDigit;

  /// No description provided for @authServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server is not responding. Please check your connection and try again.'**
  String get authServerUnreachable;

  /// No description provided for @authNoConnection.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your internet connection.'**
  String get authNoConnection;

  /// No description provided for @authSecureConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not establish a secure connection to the server.'**
  String get authSecureConnectionFailed;

  /// No description provided for @authRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request was cancelled.'**
  String get authRequestCancelled;

  /// No description provided for @authEmptyResponse.
  ///
  /// In en, this message translates to:
  /// **'Server returned an empty response.'**
  String get authEmptyResponse;

  /// No description provided for @authNoAuthToken.
  ///
  /// In en, this message translates to:
  /// **'Server did not issue an authentication token.'**
  String get authNoAuthToken;

  /// No description provided for @authConfirmationMissing.
  ///
  /// In en, this message translates to:
  /// **'Server did not return confirmation.'**
  String get authConfirmationMissing;

  /// No description provided for @onboardingStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 4 — Account'**
  String get onboardingStep1Title;

  /// No description provided for @onboardingStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'First, let\'s collect your name, email and password. The remaining steps come later.'**
  String get onboardingStep1Subtitle;

  /// No description provided for @onboardingStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 4 — Personal details'**
  String get onboardingStep2Title;

  /// No description provided for @onboardingStep2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Date of birth and gender.'**
  String get onboardingStep2Subtitle;

  /// No description provided for @onboardingStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 4 — Body and goal'**
  String get onboardingStep3Title;

  /// No description provided for @onboardingStep3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Height, weight, target weight, activity level and goal.'**
  String get onboardingStep3Subtitle;

  /// No description provided for @onboardingStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Step 4 of 4 — Nutrition and allergies'**
  String get onboardingStep4Title;

  /// No description provided for @onboardingStep4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Almost done! These fields are optional — you can fill them out later in the Profile section.'**
  String get onboardingStep4Subtitle;

  /// No description provided for @onboardingBirthday.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get onboardingBirthday;

  /// No description provided for @onboardingBirthdayRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your date of birth'**
  String get onboardingBirthdayRequired;

  /// No description provided for @onboardingBirthdayNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get onboardingBirthdayNotSet;

  /// No description provided for @onboardingGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get onboardingGender;

  /// No description provided for @onboardingGenderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get onboardingGenderMale;

  /// No description provided for @onboardingGenderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get onboardingGenderFemale;

  /// No description provided for @onboardingGenderOther.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get onboardingGenderOther;

  /// No description provided for @onboardingGenderRequired.
  ///
  /// In en, this message translates to:
  /// **'Please pick an option'**
  String get onboardingGenderRequired;

  /// No description provided for @onboardingDietaryPreferences.
  ///
  /// In en, this message translates to:
  /// **'Dietary preferences (optional)'**
  String get onboardingDietaryPreferences;

  /// No description provided for @onboardingDietaryHint.
  ///
  /// In en, this message translates to:
  /// **'For example, vegetarian, keto…'**
  String get onboardingDietaryHint;

  /// No description provided for @onboardingAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies and intolerances (optional)'**
  String get onboardingAllergies;

  /// No description provided for @onboardingAllergiesHint.
  ///
  /// In en, this message translates to:
  /// **'For example, nuts, milk…'**
  String get onboardingAllergiesHint;

  /// No description provided for @onboardingHeight.
  ///
  /// In en, this message translates to:
  /// **'Height, cm'**
  String get onboardingHeight;

  /// No description provided for @onboardingHeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 175'**
  String get onboardingHeightHint;

  /// No description provided for @onboardingCurrentWeight.
  ///
  /// In en, this message translates to:
  /// **'Current weight, kg'**
  String get onboardingCurrentWeight;

  /// No description provided for @onboardingCurrentWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 70.5'**
  String get onboardingCurrentWeightHint;

  /// No description provided for @onboardingTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'Target weight, kg'**
  String get onboardingTargetWeight;

  /// No description provided for @onboardingTargetWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 65'**
  String get onboardingTargetWeightHint;

  /// No description provided for @onboardingActivityLevel.
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get onboardingActivityLevel;

  /// No description provided for @onboardingActivityLevelRequired.
  ///
  /// In en, this message translates to:
  /// **'Please pick an activity level'**
  String get onboardingActivityLevelRequired;

  /// No description provided for @onboardingPrimaryGoal.
  ///
  /// In en, this message translates to:
  /// **'Primary goal'**
  String get onboardingPrimaryGoal;

  /// No description provided for @onboardingPrimaryGoalRequired.
  ///
  /// In en, this message translates to:
  /// **'Please pick a primary goal'**
  String get onboardingPrimaryGoalRequired;

  /// No description provided for @onboardingPaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Pace: {value} kg/week'**
  String onboardingPaceLabel(String value);

  /// No description provided for @onboardingPaceChipLabel.
  ///
  /// In en, this message translates to:
  /// **'{value} kg/wk'**
  String onboardingPaceChipLabel(String value);

  /// No description provided for @onboardingRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get onboardingRequired;

  /// No description provided for @onboardingEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a number'**
  String get onboardingEnterNumber;

  /// No description provided for @onboardingMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be greater than 0'**
  String get onboardingMustBePositive;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish registration'**
  String get onboardingFinish;

  /// No description provided for @onboardingGenericError.
  ///
  /// In en, this message translates to:
  /// **'Could not complete registration.'**
  String get onboardingGenericError;

  /// No description provided for @onboardingPartialSaveWarning.
  ///
  /// In en, this message translates to:
  /// **'Profile was created, but some details didn\'t save — fill them in later in the Profile section.'**
  String get onboardingPartialSaveWarning;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsSectionTheme;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionApiEnvironmentDebug.
  ///
  /// In en, this message translates to:
  /// **'API ENVIRONMENT (DEV ONLY)'**
  String get settingsSectionApiEnvironmentDebug;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profileSave;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @profileUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not save.'**
  String get profileUpdateError;

  /// No description provided for @profileSavePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Where from?'**
  String get profileSavePhotoTitle;

  /// No description provided for @profilePhotoCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get profilePhotoCamera;

  /// No description provided for @profilePhotoGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get profilePhotoGallery;

  /// No description provided for @profilePhotoCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop photo'**
  String get profilePhotoCropTitle;

  /// No description provided for @profilePhotoCropError.
  ///
  /// In en, this message translates to:
  /// **'Could not crop photo. Try again.'**
  String get profilePhotoCropError;

  /// No description provided for @profilePhotoReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read cropped photo.'**
  String get profilePhotoReadError;

  /// No description provided for @profilePhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Photo is too large, try a different one'**
  String get profilePhotoTooLarge;

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get profilePhotoUpdated;

  /// No description provided for @profileCameraError.
  ///
  /// In en, this message translates to:
  /// **'Could not open camera. Try picking from gallery instead.'**
  String get profileCameraError;

  /// No description provided for @profileGalleryError.
  ///
  /// In en, this message translates to:
  /// **'Could not open gallery.'**
  String get profileGalleryError;

  /// No description provided for @profileSectionBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get profileSectionBasic;

  /// No description provided for @profileSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Body measurements'**
  String get profileSectionBody;

  /// No description provided for @profileSectionGoalActivity.
  ///
  /// In en, this message translates to:
  /// **'Goal and activity'**
  String get profileSectionGoalActivity;

  /// No description provided for @profileFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileFieldName;

  /// No description provided for @profileFieldBirthday.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileFieldBirthday;

  /// No description provided for @profileFieldGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileFieldGender;

  /// No description provided for @profileMetricHeight.
  ///
  /// In en, this message translates to:
  /// **'Height, cm'**
  String get profileMetricHeight;

  /// No description provided for @profileMetricHeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 175'**
  String get profileMetricHeightHint;

  /// No description provided for @profileMetricCurrentWeight.
  ///
  /// In en, this message translates to:
  /// **'Current weight, kg'**
  String get profileMetricCurrentWeight;

  /// No description provided for @profileMetricCurrentWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 70.5'**
  String get profileMetricCurrentWeightHint;

  /// No description provided for @profileMetricTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'Target weight, kg'**
  String get profileMetricTargetWeight;

  /// No description provided for @profileMetricTargetWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 65'**
  String get profileMetricTargetWeightHint;

  /// No description provided for @profileBmiLabel.
  ///
  /// In en, this message translates to:
  /// **'BMI: {label}'**
  String profileBmiLabel(String label);

  /// No description provided for @profileViewWeightHistory.
  ///
  /// In en, this message translates to:
  /// **'View weight history'**
  String get profileViewWeightHistory;

  /// No description provided for @profilePrimaryGoal.
  ///
  /// In en, this message translates to:
  /// **'Primary goal'**
  String get profilePrimaryGoal;

  /// No description provided for @profileActivityLevel.
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get profileActivityLevel;

  /// No description provided for @profilePace.
  ///
  /// In en, this message translates to:
  /// **'Weight-loss pace: {value} kg/week'**
  String profilePace(String value);

  /// No description provided for @profilePaceChip.
  ///
  /// In en, this message translates to:
  /// **'{value} kg/wk'**
  String profilePaceChip(String value);

  /// No description provided for @profileDietaryPreferences.
  ///
  /// In en, this message translates to:
  /// **'Dietary preferences'**
  String get profileDietaryPreferences;

  /// No description provided for @profileDietaryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. vegetarian…'**
  String get profileDietaryHint;

  /// No description provided for @profileAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies and intolerances'**
  String get profileAllergies;

  /// No description provided for @profileAllergiesAiHint.
  ///
  /// In en, this message translates to:
  /// **'Used by AI photo recognition to flag conflicts.'**
  String get profileAllergiesAiHint;

  /// No description provided for @profileAllergiesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. nuts…'**
  String get profileAllergiesHint;

  /// No description provided for @profileBmiUnderweight.
  ///
  /// In en, this message translates to:
  /// **'Underweight'**
  String get profileBmiUnderweight;

  /// No description provided for @profileBmiNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get profileBmiNormal;

  /// No description provided for @profileBmiOverweight.
  ///
  /// In en, this message translates to:
  /// **'Overweight'**
  String get profileBmiOverweight;

  /// No description provided for @profileBmiObese.
  ///
  /// In en, this message translates to:
  /// **'Obese'**
  String get profileBmiObese;

  /// No description provided for @dietVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get dietVegetarian;

  /// No description provided for @dietVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get dietVegan;

  /// No description provided for @dietKeto.
  ///
  /// In en, this message translates to:
  /// **'Keto'**
  String get dietKeto;

  /// No description provided for @dietPaleo.
  ///
  /// In en, this message translates to:
  /// **'Paleo'**
  String get dietPaleo;

  /// No description provided for @dietLowCarb.
  ///
  /// In en, this message translates to:
  /// **'Low-carb'**
  String get dietLowCarb;

  /// No description provided for @dietLowFat.
  ///
  /// In en, this message translates to:
  /// **'Low-fat'**
  String get dietLowFat;

  /// No description provided for @dietMediterranean.
  ///
  /// In en, this message translates to:
  /// **'Mediterranean'**
  String get dietMediterranean;

  /// No description provided for @dietHalal.
  ///
  /// In en, this message translates to:
  /// **'Halal'**
  String get dietHalal;

  /// No description provided for @dietKosher.
  ///
  /// In en, this message translates to:
  /// **'Kosher'**
  String get dietKosher;

  /// No description provided for @allergyNuts.
  ///
  /// In en, this message translates to:
  /// **'Nuts'**
  String get allergyNuts;

  /// No description provided for @allergyShellfish.
  ///
  /// In en, this message translates to:
  /// **'Shellfish'**
  String get allergyShellfish;

  /// No description provided for @allergyEggs.
  ///
  /// In en, this message translates to:
  /// **'Eggs'**
  String get allergyEggs;

  /// No description provided for @allergySoy.
  ///
  /// In en, this message translates to:
  /// **'Soy'**
  String get allergySoy;

  /// No description provided for @allergyWheat.
  ///
  /// In en, this message translates to:
  /// **'Wheat'**
  String get allergyWheat;

  /// No description provided for @allergyFish.
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get allergyFish;

  /// No description provided for @allergyMilk.
  ///
  /// In en, this message translates to:
  /// **'Milk'**
  String get allergyMilk;

  /// No description provided for @activitySedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get activitySedentary;

  /// No description provided for @activityLightlyActive.
  ///
  /// In en, this message translates to:
  /// **'Lightly active'**
  String get activityLightlyActive;

  /// No description provided for @activityModeratelyActive.
  ///
  /// In en, this message translates to:
  /// **'Moderately active'**
  String get activityModeratelyActive;

  /// No description provided for @activityVeryActive.
  ///
  /// In en, this message translates to:
  /// **'Very active'**
  String get activityVeryActive;

  /// No description provided for @activityExtraActive.
  ///
  /// In en, this message translates to:
  /// **'Extra active'**
  String get activityExtraActive;

  /// No description provided for @goalLoseWeight.
  ///
  /// In en, this message translates to:
  /// **'Lose weight'**
  String get goalLoseWeight;

  /// No description provided for @goalMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain weight'**
  String get goalMaintain;

  /// No description provided for @goalGainMuscle.
  ///
  /// In en, this message translates to:
  /// **'Gain muscle'**
  String get goalGainMuscle;

  /// No description provided for @goalEatHealthier.
  ///
  /// In en, this message translates to:
  /// **'Eat healthier'**
  String get goalEatHealthier;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible'**
  String get deleteAccountWarningTitle;

  /// No description provided for @deleteAccountWarningBody.
  ///
  /// In en, this message translates to:
  /// **'These will be permanently deleted: your profile, food log history, weight history, photos, and chat history with the AI assistant. This cannot be undone.'**
  String get deleteAccountWarningBody;

  /// No description provided for @deleteAccountAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand that this action cannot be undone'**
  String get deleteAccountAcknowledge;

  /// No description provided for @deleteAccountAcknowledgeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm that you understand the risk'**
  String get deleteAccountAcknowledgeRequired;

  /// No description provided for @deleteAccountCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get deleteAccountCurrentPassword;

  /// No description provided for @deleteAccountCurrentPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password'**
  String get deleteAccountCurrentPasswordRequired;

  /// No description provided for @deleteAccountHelperBeforeAck.
  ///
  /// In en, this message translates to:
  /// **'First, confirm that you understand the risk'**
  String get deleteAccountHelperBeforeAck;

  /// No description provided for @deleteAccountHelperAfterAck.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password to continue'**
  String get deleteAccountHelperAfterAck;

  /// No description provided for @deleteAccountConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete account permanently'**
  String get deleteAccountConfirmButton;

  /// No description provided for @deleteAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account for real?'**
  String get deleteAccountDialogTitle;

  /// No description provided for @deleteAccountDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This is your final warning. All your data will be deleted and cannot be recovered.'**
  String get deleteAccountDialogBody;

  /// No description provided for @deleteAccountWrongPasswordMatch.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get deleteAccountWrongPasswordMatch;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changePasswordCurrent;

  /// No description provided for @changePasswordCurrentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password'**
  String get changePasswordCurrentRequired;

  /// No description provided for @changePasswordNew.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get changePasswordNew;

  /// No description provided for @changePasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get changePasswordConfirm;

  /// No description provided for @changePasswordConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get changePasswordConfirmRequired;

  /// No description provided for @changePasswordSave.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordSave;

  /// No description provided for @trackerTitle.
  ///
  /// In en, this message translates to:
  /// **'Tracker'**
  String get trackerTitle;

  /// No description provided for @trackerDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get trackerDateToday;

  /// No description provided for @trackerDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get trackerDateYesterday;

  /// No description provided for @trackerDeleteRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete record?'**
  String get trackerDeleteRecordTitle;

  /// No description provided for @trackerDeleteRecordBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from today\'s log.'**
  String trackerDeleteRecordBody(String name);

  /// No description provided for @trackerMealPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Which meal does this belong to?'**
  String get trackerMealPickerTitle;

  /// No description provided for @trackerCameraChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'What are we photographing?'**
  String get trackerCameraChoiceTitle;

  /// No description provided for @trackerCameraFood.
  ///
  /// In en, this message translates to:
  /// **'Photograph food'**
  String get trackerCameraFood;

  /// No description provided for @trackerCameraFoodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Identify macros and add an entry to the log'**
  String get trackerCameraFoodSubtitle;

  /// No description provided for @trackerCameraBeverage.
  ///
  /// In en, this message translates to:
  /// **'Photograph beverage'**
  String get trackerCameraBeverage;

  /// No description provided for @trackerCameraBeverageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-add water and calories in one step'**
  String get trackerCameraBeverageSubtitle;

  /// No description provided for @trackerEmptyLog.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get trackerEmptyLog;

  /// No description provided for @trackerFoodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{calories} kcal • P/C/F {protein}/{carbs}/{fat} g'**
  String trackerFoodSubtitle(
    String calories,
    String protein,
    String carbs,
    String fat,
  );

  /// No description provided for @trackerCaloriesToday.
  ///
  /// In en, this message translates to:
  /// **'Calories today'**
  String get trackerCaloriesToday;

  /// No description provided for @trackerCaloriesEaten.
  ///
  /// In en, this message translates to:
  /// **'Calories consumed'**
  String get trackerCaloriesEaten;

  /// No description provided for @trackerCaloriesKcalOf.
  ///
  /// In en, this message translates to:
  /// **' / {target} kcal'**
  String trackerCaloriesKcalOf(String target);

  /// No description provided for @trackerCaloriesKcalOnly.
  ///
  /// In en, this message translates to:
  /// **' kcal'**
  String get trackerCaloriesKcalOnly;

  /// No description provided for @trackerWaterTitle.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get trackerWaterTitle;

  /// No description provided for @trackerWaterGoalReached.
  ///
  /// In en, this message translates to:
  /// **'Daily goal reached!'**
  String get trackerWaterGoalReached;

  /// No description provided for @trackerWaterPctOfGoal.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of daily goal'**
  String trackerWaterPctOfGoal(String pct);

  /// No description provided for @trackerWaterRemaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} remaining'**
  String trackerWaterRemaining(String amount);

  /// No description provided for @trackerWaterError.
  ///
  /// In en, this message translates to:
  /// **'Could not save.'**
  String get trackerWaterError;

  /// No description provided for @trackerWaterAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add water'**
  String get trackerWaterAddTitle;

  /// No description provided for @trackerWaterAddInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter amount in litres (0.1–10 L)'**
  String get trackerWaterAddInstructions;

  /// No description provided for @trackerWaterLiters.
  ///
  /// In en, this message translates to:
  /// **'Litres'**
  String get trackerWaterLiters;

  /// No description provided for @trackerWaterHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 0.5'**
  String get trackerWaterHint;

  /// No description provided for @trackerWaterRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the amount'**
  String get trackerWaterRequired;

  /// No description provided for @trackerWaterMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum is 0.1 L'**
  String get trackerWaterMin;

  /// No description provided for @trackerWaterMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum is 10 L'**
  String get trackerWaterMax;

  /// No description provided for @trackerWeightCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get trackerWeightCardTitle;

  /// No description provided for @trackerWeightCardCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current weight: {value} kg'**
  String trackerWeightCardCurrent(String value);

  /// No description provided for @trackerWeightCardAdd.
  ///
  /// In en, this message translates to:
  /// **'Add weight'**
  String get trackerWeightCardAdd;

  /// No description provided for @trackerDockCameraTooltip.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get trackerDockCameraTooltip;

  /// No description provided for @trackerDockChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Chat with NutriBot'**
  String get trackerDockChatTooltip;

  /// No description provided for @trackerDockAddFoodTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get trackerDockAddFoodTooltip;

  /// No description provided for @trackerDockProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get trackerDockProfileTooltip;

  /// No description provided for @trackerDockSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get trackerDockSettingsTooltip;

  /// No description provided for @trackerDatePrevTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get trackerDatePrevTooltip;

  /// No description provided for @trackerDateNextTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get trackerDateNextTooltip;

  /// No description provided for @trackerTooltipDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get trackerTooltipDelete;

  /// No description provided for @trackerTooltipRefine.
  ///
  /// In en, this message translates to:
  /// **'Refine'**
  String get trackerTooltipRefine;

  /// No description provided for @trackerMealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get trackerMealBreakfast;

  /// No description provided for @trackerMealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get trackerMealLunch;

  /// No description provided for @trackerMealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get trackerMealDinner;

  /// No description provided for @trackerMealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get trackerMealSnack;

  /// No description provided for @trackerMealDrinks.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get trackerMealDrinks;

  /// No description provided for @addFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get addFoodTitle;

  /// No description provided for @addFoodMealLabel.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get addFoodMealLabel;

  /// No description provided for @addFoodMealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get addFoodMealBreakfast;

  /// No description provided for @addFoodMealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get addFoodMealLunch;

  /// No description provided for @addFoodMealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get addFoodMealDinner;

  /// No description provided for @addFoodMealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get addFoodMealSnack;

  /// No description provided for @addFoodName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get addFoodName;

  /// No description provided for @addFoodQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get addFoodQuantity;

  /// No description provided for @addFoodUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get addFoodUnit;

  /// No description provided for @addFoodUnitG.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get addFoodUnitG;

  /// No description provided for @addFoodUnitMl.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get addFoodUnitMl;

  /// No description provided for @addFoodUnitPcs.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get addFoodUnitPcs;

  /// No description provided for @addFoodCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories, kcal'**
  String get addFoodCalories;

  /// No description provided for @addFoodProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein, g'**
  String get addFoodProtein;

  /// No description provided for @addFoodCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs, g'**
  String get addFoodCarbs;

  /// No description provided for @addFoodFat.
  ///
  /// In en, this message translates to:
  /// **'Fat, g'**
  String get addFoodFat;

  /// No description provided for @addFoodFiber.
  ///
  /// In en, this message translates to:
  /// **'Fiber, g (optional)'**
  String get addFoodFiber;

  /// No description provided for @addFoodButtonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addFoodButtonAdd;

  /// No description provided for @addFoodFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in \"{label}\"'**
  String addFoodFieldRequired(String label);

  /// No description provided for @addFoodEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a number'**
  String get addFoodEnterNumber;

  /// No description provided for @addFoodMustBeNonNegative.
  ///
  /// In en, this message translates to:
  /// **'Must be ≥ 0'**
  String get addFoodMustBeNonNegative;

  /// No description provided for @addFoodMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be > 0'**
  String get addFoodMustBePositive;

  /// No description provided for @photoFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo of food'**
  String get photoFoodTitle;

  /// No description provided for @photoFoodCameraError.
  ///
  /// In en, this message translates to:
  /// **'Could not open camera. Try picking from gallery instead.'**
  String get photoFoodCameraError;

  /// No description provided for @photoFoodGalleryError.
  ///
  /// In en, this message translates to:
  /// **'Could not open gallery.'**
  String get photoFoodGalleryError;

  /// No description provided for @photoFoodInstructions.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of your food or pick one from the gallery'**
  String get photoFoodInstructions;

  /// No description provided for @photoFoodTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photoFoodTakePhoto;

  /// No description provided for @photoFoodPickGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get photoFoodPickGallery;

  /// No description provided for @photoFoodAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing photo…'**
  String get photoFoodAnalyzing;

  /// No description provided for @photoFoodErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize the dish in the photo. Try a clearer photo.'**
  String get photoFoodErrorTitle;

  /// No description provided for @photoFoodAllergyWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Possible allergy conflict'**
  String get photoFoodAllergyWarningTitle;

  /// No description provided for @photoFoodAllergyWarningBullet.
  ///
  /// In en, this message translates to:
  /// **'•  {text}'**
  String photoFoodAllergyWarningBullet(String text);

  /// No description provided for @photoFoodNoName.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get photoFoodNoName;

  /// No description provided for @photoFoodIngredientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ingredients detected'**
  String get photoFoodIngredientsTitle;

  /// No description provided for @photoBeverageTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo of beverage'**
  String get photoBeverageTitle;

  /// No description provided for @photoBeverageInstructions.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of your drink or pick one from the gallery'**
  String get photoBeverageInstructions;

  /// No description provided for @photoBeverageAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing photo…'**
  String get photoBeverageAnalyzing;

  /// No description provided for @photoBeverageSugar.
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get photoBeverageSugar;

  /// No description provided for @photoBeverageMl.
  ///
  /// In en, this message translates to:
  /// **'{value} ml'**
  String photoBeverageMl(String value);

  /// No description provided for @photoBeverageUnsure.
  ///
  /// In en, this message translates to:
  /// **'Not sure about the identification — please review and confirm the details.'**
  String get photoBeverageUnsure;

  /// No description provided for @photoBeverageDescriptionMissing.
  ///
  /// In en, this message translates to:
  /// **'— no description'**
  String get photoBeverageDescriptionMissing;

  /// No description provided for @photoBeverageNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Beverage name'**
  String get photoBeverageNameLabel;

  /// No description provided for @photoBeverageNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the name'**
  String get photoBeverageNameRequired;

  /// No description provided for @photoBeverageVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Volume, ml'**
  String get photoBeverageVolumeLabel;

  /// No description provided for @photoBeverageVolumeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the volume'**
  String get photoBeverageVolumeRequired;

  /// No description provided for @photoBeverageCaloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Calories, kcal'**
  String get photoBeverageCaloriesLabel;

  /// No description provided for @photoBeverageMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details (protein, fat, carbs, sugar)'**
  String get photoBeverageMoreDetails;

  /// No description provided for @photoBeverageProteinLabel.
  ///
  /// In en, this message translates to:
  /// **'Protein, g'**
  String get photoBeverageProteinLabel;

  /// No description provided for @photoBeverageCarbsLabel.
  ///
  /// In en, this message translates to:
  /// **'Carbs, g'**
  String get photoBeverageCarbsLabel;

  /// No description provided for @photoBeverageFatLabel.
  ///
  /// In en, this message translates to:
  /// **'Fat, g'**
  String get photoBeverageFatLabel;

  /// No description provided for @photoBeverageSugarLabel.
  ///
  /// In en, this message translates to:
  /// **'Sugar, g'**
  String get photoBeverageSugarLabel;

  /// No description provided for @photoBeverageNonNegative.
  ///
  /// In en, this message translates to:
  /// **'Must be ≥ 0'**
  String get photoBeverageNonNegative;

  /// No description provided for @photoBeveragePositiveRequired.
  ///
  /// In en, this message translates to:
  /// **'Volume must be greater than 0'**
  String get photoBeveragePositiveRequired;

  /// No description provided for @photoBeverageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm and save'**
  String get photoBeverageConfirm;

  /// No description provided for @photoBeverageSaved.
  ///
  /// In en, this message translates to:
  /// **'Beverage saved'**
  String get photoBeverageSaved;

  /// No description provided for @photoBeverageSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the beverage. Try again.'**
  String get photoBeverageSaveError;

  /// No description provided for @photoBeverageMismatchWarning.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look like \"{name}\" in the photo.'**
  String photoBeverageMismatchWarning(String name);

  /// No description provided for @photoBeverageMismatchLooksLike.
  ///
  /// In en, this message translates to:
  /// **'Looks more like: {suggestion}.'**
  String photoBeverageMismatchLooksLike(String suggestion);

  /// No description provided for @photoBeverageMismatchFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get photoBeverageMismatchFix;

  /// No description provided for @photoBeverageMismatchProceed.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get photoBeverageMismatchProceed;

  /// No description provided for @photoBeverageVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify the photo match — saved without verification.'**
  String get photoBeverageVerifyFailed;

  /// No description provided for @editFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Refine description'**
  String get editFoodTitle;

  /// No description provided for @editFoodHint.
  ///
  /// In en, this message translates to:
  /// **'For example: this is brown rice, not white, and there is less oil'**
  String get editFoodHint;

  /// No description provided for @editFoodRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description — it will be sent to the AI for re-estimation.'**
  String get editFoodRequired;

  /// No description provided for @editFoodHelpText.
  ///
  /// In en, this message translates to:
  /// **'Describe what is really in the dish — this will help the AI recalculate calories and macros more accurately. The image is not used.'**
  String get editFoodHelpText;

  /// No description provided for @editFoodRecalculate.
  ///
  /// In en, this message translates to:
  /// **'Recalculate'**
  String get editFoodRecalculate;

  /// No description provided for @editFoodAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing description…'**
  String get editFoodAnalyzing;

  /// No description provided for @editFoodConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High confidence'**
  String get editFoodConfidenceHigh;

  /// No description provided for @editFoodConfidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium confidence'**
  String get editFoodConfidenceMedium;

  /// No description provided for @editFoodConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get editFoodConfidenceLow;

  /// No description provided for @editFoodNoDescription.
  ///
  /// In en, this message translates to:
  /// **'— no description'**
  String get editFoodNoDescription;

  /// No description provided for @editFoodRecalcBadge.
  ///
  /// In en, this message translates to:
  /// **'Recalculated'**
  String get editFoodRecalcBadge;

  /// No description provided for @trackerFoodProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get trackerFoodProtein;

  /// No description provided for @trackerFoodCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get trackerFoodCarbs;

  /// No description provided for @trackerFoodFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get trackerFoodFat;

  /// No description provided for @weightHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight history'**
  String get weightHistoryTitle;

  /// No description provided for @weightHistoryAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add weight entry'**
  String get weightHistoryAddTitle;

  /// No description provided for @weightHistoryWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight, kg'**
  String get weightHistoryWeight;

  /// No description provided for @weightHistoryWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 70.5'**
  String get weightHistoryWeightHint;

  /// No description provided for @weightHistoryWeightRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a weight'**
  String get weightHistoryWeightRequired;

  /// No description provided for @weightHistoryWeightMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Weight must be greater than 0'**
  String get weightHistoryWeightMustBePositive;

  /// No description provided for @weightHistoryNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get weightHistoryNote;

  /// No description provided for @weightHistoryNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. morning weigh-in'**
  String get weightHistoryNoteHint;

  /// No description provided for @weightHistorySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get weightHistorySave;

  /// No description provided for @weightHistoryErrorSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save.'**
  String get weightHistoryErrorSave;

  /// No description provided for @weightHistoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get weightHistoryDeleteTitle;

  /// No description provided for @weightHistoryDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This weight entry will be permanently deleted.'**
  String get weightHistoryDeleteBody;

  /// No description provided for @weightHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No weight entries yet'**
  String get weightHistoryEmpty;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatClearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all chat history?'**
  String get chatClearHistoryTitle;

  /// No description provided for @chatClearHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get chatClearHistoryBody;

  /// No description provided for @chatClearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get chatClearHistoryConfirm;

  /// No description provided for @chatMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get chatMenuTooltip;

  /// No description provided for @chatMenuClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get chatMenuClearHistory;

  /// No description provided for @chatEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Ask me about nutrition, calorie goals, or foods!'**
  String get chatEmptyState;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about nutrition…'**
  String get chatInputHint;

  /// No description provided for @chatSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSendTooltip;

  /// No description provided for @chatError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get chatError;

  /// No description provided for @emailVerifyBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Verify your email so you don\'t lose access to your account.'**
  String get emailVerifyBannerMessage;

  /// No description provided for @emailVerifyBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get emailVerifyBannerAction;

  /// No description provided for @emailVerifyBannerDismissTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get emailVerifyBannerDismissTooltip;

  /// No description provided for @apiEnvCardTitle.
  ///
  /// In en, this message translates to:
  /// **'API environment (dev only)'**
  String get apiEnvCardTitle;

  /// No description provided for @apiEnvCardCurrentUrl.
  ///
  /// In en, this message translates to:
  /// **'Current URL'**
  String get apiEnvCardCurrentUrl;

  /// No description provided for @apiEnvCardBaseUrlApplied.
  ///
  /// In en, this message translates to:
  /// **'Base URL: {url}'**
  String apiEnvCardBaseUrlApplied(String url);

  /// No description provided for @apiEnvCardBaseUrlAppliedBody.
  ///
  /// In en, this message translates to:
  /// **'New requests will use it. Pull-to-refresh or navigate to another section to update already-loaded screens.'**
  String get apiEnvCardBaseUrlAppliedBody;

  /// No description provided for @apiEnvCardPresets.
  ///
  /// In en, this message translates to:
  /// **'Quick presets'**
  String get apiEnvCardPresets;

  /// No description provided for @apiEnvCardPresetIos.
  ///
  /// In en, this message translates to:
  /// **'iOS Simulator (localhost)'**
  String get apiEnvCardPresetIos;

  /// No description provided for @apiEnvCardPresetAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android Emulator'**
  String get apiEnvCardPresetAndroid;

  /// No description provided for @apiEnvCardCustomUrl.
  ///
  /// In en, this message translates to:
  /// **'Custom URL (e.g. for a device on the local network)'**
  String get apiEnvCardCustomUrl;

  /// No description provided for @apiEnvCardBaseUrlField.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get apiEnvCardBaseUrlField;

  /// No description provided for @apiEnvCardBaseUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL'**
  String get apiEnvCardBaseUrlRequired;

  /// No description provided for @apiEnvCardBaseUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'URL must start with http:// or https://'**
  String get apiEnvCardBaseUrlInvalid;

  /// No description provided for @apiEnvCardApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apiEnvCardApply;

  /// No description provided for @apiEnvCardReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get apiEnvCardReset;

  /// No description provided for @tagInputDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Type and press Enter…'**
  String get tagInputDefaultHint;

  /// No description provided for @userFacingErrorServerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Server returned an empty response.'**
  String get userFacingErrorServerEmpty;

  /// No description provided for @userFacingErrorFoodPhotoRecognize.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize the dish in the photo. Try a clearer photo.'**
  String get userFacingErrorFoodPhotoRecognize;

  /// No description provided for @userFacingErrorFoodReanalyze.
  ///
  /// In en, this message translates to:
  /// **'Could not analyze the description. Try rephrasing.'**
  String get userFacingErrorFoodReanalyze;

  /// No description provided for @userFacingErrorBeverageRecognize.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize the beverage. Try a different photo.'**
  String get userFacingErrorBeverageRecognize;

  /// No description provided for @userFacingErrorPhotoProcess.
  ///
  /// In en, this message translates to:
  /// **'Could not process the photo. Try again.'**
  String get userFacingErrorPhotoProcess;

  /// No description provided for @userFacingErrorDescriptionProcess.
  ///
  /// In en, this message translates to:
  /// **'Could not process the description. Try again.'**
  String get userFacingErrorDescriptionProcess;

  /// No description provided for @userFacingErrorUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not upload photo. Check file size (max. 5 MB).'**
  String get userFacingErrorUploadPhoto;

  /// No description provided for @userFacingErrorPhotoUrl.
  ///
  /// In en, this message translates to:
  /// **'Server did not return a photo URL.'**
  String get userFacingErrorPhotoUrl;

  /// No description provided for @onboardingRequiredField.
  ///
  /// In en, this message translates to:
  /// **'Please fill in «{label}»'**
  String onboardingRequiredField(String label);

  /// No description provided for @homeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get homeLoading;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}!'**
  String homeGreeting(String name);

  /// No description provided for @homeTrackerPreview.
  ///
  /// In en, this message translates to:
  /// **'Here will be the nutrition tracker.'**
  String get homeTrackerPreview;

  /// No description provided for @homeLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get homeLogout;

  /// No description provided for @photoBeverageCameraError.
  ///
  /// In en, this message translates to:
  /// **'Could not open camera. Try picking from gallery instead.'**
  String get photoBeverageCameraError;

  /// No description provided for @photoBeverageGalleryError.
  ///
  /// In en, this message translates to:
  /// **'Could not open gallery.'**
  String get photoBeverageGalleryError;

  /// No description provided for @photoBeverageTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photoBeverageTakePhoto;

  /// No description provided for @photoBeveragePickGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get photoBeveragePickGallery;

  /// No description provided for @trackerWaterProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {goal}'**
  String trackerWaterProgress(Object current, Object goal);

  /// No description provided for @photoFoodConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High confidence'**
  String get photoFoodConfidenceHigh;

  /// No description provided for @photoFoodConfidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium confidence'**
  String get photoFoodConfidenceMedium;

  /// No description provided for @photoFoodConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get photoFoodConfidenceLow;

  /// No description provided for @photoBeverageConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High confidence'**
  String get photoBeverageConfidenceHigh;

  /// No description provided for @photoBeverageConfidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium confidence'**
  String get photoBeverageConfidenceMedium;

  /// No description provided for @photoBeverageConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get photoBeverageConfidenceLow;

  /// No description provided for @macroProteinShort.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get macroProteinShort;

  /// No description provided for @macroCarbsShort.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get macroCarbsShort;

  /// No description provided for @macroFatShort.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get macroFatShort;

  /// No description provided for @macroSugarShort.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get macroSugarShort;

  /// No description provided for @unitGramsShort.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitGramsShort;

  /// No description provided for @unitKcalShort.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get unitKcalShort;

  /// No description provided for @weightHistoryLatestMissing.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get weightHistoryLatestMissing;

  /// No description provided for @weightHistoryTarget.
  ///
  /// In en, this message translates to:
  /// **'Goal: {value} kg'**
  String weightHistoryTarget(String value);

  /// No description provided for @weightHistoryRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {value} kg'**
  String weightHistoryRemaining(String value);

  /// No description provided for @weightHistoryChartGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get weightHistoryChartGoalLabel;

  /// No description provided for @weightHistoryMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be > 0'**
  String get weightHistoryMustBePositive;

  /// No description provided for @weightHistoryTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Value too large'**
  String get weightHistoryTooLarge;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ka', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ka':
      return AppLocalizationsKa();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
