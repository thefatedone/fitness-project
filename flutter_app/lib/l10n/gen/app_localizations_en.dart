// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NutriMind';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDone => 'Done';

  @override
  String get commonYesDelete => 'Yes, delete';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClose => 'Close';

  @override
  String get commonError =>
      'Something went wrong. Please check your connection and try again.';

  @override
  String get commonErrorShort => 'Something went wrong. Try again.';

  @override
  String get commonErrorWithRetry => 'Something went wrong. Try again.';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDescriptionLight => 'Always use the light theme.';

  @override
  String get themeDescriptionDark => 'Always use the dark theme.';

  @override
  String get themeDescriptionSystem => 'Theme follows your system setting.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGeorgian => 'ქართული';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageSectionLabel => 'Language';

  @override
  String get languageFieldTheme => 'Theme';

  @override
  String get authLoginTitle => 'NutriMind';

  @override
  String get authLoginSubtitle => 'Welcome back';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailRequired => 'Please enter your email';

  @override
  String get authEmailInvalid => 'That doesn\'t look like a valid email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordRequired => 'Please enter your password';

  @override
  String get authPasswordHelper =>
      'Min. 8 characters, one uppercase letter, one digit';

  @override
  String get authLoginButton => 'Log in';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNoAccountRegister => 'Don\'t have an account? Sign up';

  @override
  String get authServerDebugLink => 'Server settings (debug)';

  @override
  String get authSessionExpired => 'Your session expired, please log in again.';

  @override
  String get authRegisterTitle => 'Sign up';

  @override
  String get authRegisterName => 'Full name';

  @override
  String get authRegisterNameRequired => 'Please enter your name';

  @override
  String get authRegisterPassword => 'Password';

  @override
  String get authRegisterCreate => 'Create account';

  @override
  String get authForgotTitle => 'Reset password';

  @override
  String get authForgotInstructions =>
      'Enter the email associated with your account — we\'ll send a code to reset your password.';

  @override
  String get authForgotSendCode => 'Send code';

  @override
  String get authCodeTitle => 'Enter code';

  @override
  String authCodeInstructions(String email) {
    return 'We sent a code to $email';
  }

  @override
  String get authCodeField => 'Code';

  @override
  String get authCodeRequired => 'Code must be 6 digits';

  @override
  String get authCodeConfirm => 'Confirm';

  @override
  String get authCodeResend => 'Resend code';

  @override
  String get authResetTitle => 'New password';

  @override
  String authResetInstructions(String email) {
    return 'Enter a new password for $email';
  }

  @override
  String get authResetNewPassword => 'New password';

  @override
  String get authResetConfirmPassword => 'Confirm password';

  @override
  String get authResetConfirmRequired => 'Please confirm your password';

  @override
  String get authResetMismatch => 'Passwords don\'t match';

  @override
  String get authResetSave => 'Save new password';

  @override
  String get authResetSuccess => 'Password changed. You can now log in.';

  @override
  String get authEmailVerifyTitle => 'Verify your email';

  @override
  String authEmailVerifyInstructions(String email) {
    return 'We\'ll send a verification code to $email';
  }

  @override
  String get authEmailVerifyEnterCode => 'Enter the code from the email';

  @override
  String get authEmailVerifySendCode => 'Send code';

  @override
  String get authEmailVerifyResend => 'Resend code';

  @override
  String get authPasswordMinLength => 'Password must be at least 8 characters';

  @override
  String get authPasswordNeedUpper =>
      'First letter of the password must be uppercase';

  @override
  String get authPasswordNeedDigit =>
      'Password must contain at least one digit';

  @override
  String get authServerUnreachable =>
      'Server is not responding. Please check your connection and try again.';

  @override
  String get authNoConnection =>
      'Cannot reach the server. Check your internet connection.';

  @override
  String get authSecureConnectionFailed =>
      'Could not establish a secure connection to the server.';

  @override
  String get authRequestCancelled => 'Request was cancelled.';

  @override
  String get authEmptyResponse => 'Server returned an empty response.';

  @override
  String get authNoAuthToken => 'Server did not issue an authentication token.';

  @override
  String get authConfirmationMissing => 'Server did not return confirmation.';

  @override
  String get onboardingStep1Title => 'Step 1 of 4 — Account';

  @override
  String get onboardingStep1Subtitle =>
      'First, let\'s collect your name, email and password. The remaining steps come later.';

  @override
  String get onboardingStep2Title => 'Step 2 of 4 — Personal details';

  @override
  String get onboardingStep2Subtitle => 'Date of birth and gender.';

  @override
  String get onboardingStep3Title => 'Step 3 of 4 — Body and goal';

  @override
  String get onboardingStep3Subtitle =>
      'Height, weight, target weight, activity level and goal.';

  @override
  String get onboardingStep4Title => 'Step 4 of 4 — Nutrition and allergies';

  @override
  String get onboardingStep4Subtitle =>
      'Almost done! These fields are optional — you can fill them out later in the Profile section.';

  @override
  String get onboardingBirthday => 'Date of birth';

  @override
  String get onboardingBirthdayRequired => 'Please enter your date of birth';

  @override
  String get onboardingBirthdayNotSet => 'Not set';

  @override
  String get onboardingGender => 'Gender';

  @override
  String get onboardingGenderMale => 'Male';

  @override
  String get onboardingGenderFemale => 'Female';

  @override
  String get onboardingGenderOther => 'Prefer not to say';

  @override
  String get onboardingGenderRequired => 'Please pick an option';

  @override
  String get onboardingDietaryPreferences => 'Dietary preferences (optional)';

  @override
  String get onboardingDietaryHint => 'For example, vegetarian, keto…';

  @override
  String get onboardingAllergies => 'Allergies and intolerances (optional)';

  @override
  String get onboardingAllergiesHint => 'For example, nuts, milk…';

  @override
  String get onboardingHeight => 'Height, cm';

  @override
  String get onboardingHeightHint => 'e.g. 175';

  @override
  String get onboardingCurrentWeight => 'Current weight, kg';

  @override
  String get onboardingCurrentWeightHint => 'e.g. 70.5';

  @override
  String get onboardingTargetWeight => 'Target weight, kg';

  @override
  String get onboardingTargetWeightHint => 'e.g. 65';

  @override
  String get onboardingActivityLevel => 'Activity level';

  @override
  String get onboardingActivityLevelRequired => 'Please pick an activity level';

  @override
  String get onboardingPrimaryGoal => 'Primary goal';

  @override
  String get onboardingPrimaryGoalRequired => 'Please pick a primary goal';

  @override
  String onboardingPaceLabel(String value) {
    return 'Pace: $value kg/week';
  }

  @override
  String onboardingPaceChipLabel(String value) {
    return '$value kg/wk';
  }

  @override
  String get onboardingRequired => 'Required';

  @override
  String get onboardingEnterNumber => 'Please enter a number';

  @override
  String get onboardingMustBePositive => 'Must be greater than 0';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingFinish => 'Finish registration';

  @override
  String get onboardingGenericError => 'Could not complete registration.';

  @override
  String get onboardingPartialSaveWarning =>
      'Profile was created, but some details didn\'t save — fill them in later in the Profile section.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'APPEARANCE';

  @override
  String get settingsSectionTheme => 'Theme';

  @override
  String get settingsSectionAccount => 'ACCOUNT';

  @override
  String get settingsSectionAbout => 'ABOUT';

  @override
  String get settingsSectionApiEnvironmentDebug => 'API ENVIRONMENT (DEV ONLY)';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSave => 'Save changes';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get profileUpdateError => 'Could not save.';

  @override
  String get profileSavePhotoTitle => 'Where from?';

  @override
  String get profilePhotoCamera => 'Take a photo';

  @override
  String get profilePhotoGallery => 'Pick from gallery';

  @override
  String get profilePhotoCropTitle => 'Crop photo';

  @override
  String get profilePhotoCropError => 'Could not crop photo. Try again.';

  @override
  String get profilePhotoReadError => 'Could not read cropped photo.';

  @override
  String get profilePhotoTooLarge => 'Photo is too large, try a different one';

  @override
  String get profilePhotoUpdated => 'Photo updated';

  @override
  String get profileCameraError =>
      'Could not open camera. Try picking from gallery instead.';

  @override
  String get profileGalleryError => 'Could not open gallery.';

  @override
  String get profileSectionBasic => 'Basic';

  @override
  String get profileSectionBody => 'Body measurements';

  @override
  String get profileSectionGoalActivity => 'Goal and activity';

  @override
  String get profileFieldName => 'Name';

  @override
  String get profileFieldBirthday => 'Date of birth';

  @override
  String get profileFieldGender => 'Gender';

  @override
  String get profileMetricHeight => 'Height, cm';

  @override
  String get profileMetricHeightHint => 'e.g. 175';

  @override
  String get profileMetricCurrentWeight => 'Current weight, kg';

  @override
  String get profileMetricCurrentWeightHint => 'e.g. 70.5';

  @override
  String get profileMetricTargetWeight => 'Target weight, kg';

  @override
  String get profileMetricTargetWeightHint => 'e.g. 65';

  @override
  String profileBmiLabel(String label) {
    return 'BMI: $label';
  }

  @override
  String get profileViewWeightHistory => 'View weight history';

  @override
  String get profilePrimaryGoal => 'Primary goal';

  @override
  String get profileActivityLevel => 'Activity level';

  @override
  String profilePace(String value) {
    return 'Weight-loss pace: $value kg/week';
  }

  @override
  String profilePaceChip(String value) {
    return '$value kg/wk';
  }

  @override
  String get profileDietaryPreferences => 'Dietary preferences';

  @override
  String get profileDietaryHint => 'e.g. vegetarian…';

  @override
  String get profileAllergies => 'Allergies and intolerances';

  @override
  String get profileAllergiesAiHint =>
      'Used by AI photo recognition to flag conflicts.';

  @override
  String get profileAllergiesHint => 'e.g. nuts…';

  @override
  String get profileBmiUnderweight => 'Underweight';

  @override
  String get profileBmiNormal => 'Normal';

  @override
  String get profileBmiOverweight => 'Overweight';

  @override
  String get profileBmiObese => 'Obese';

  @override
  String get dietVegetarian => 'Vegetarian';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietKeto => 'Keto';

  @override
  String get dietPaleo => 'Paleo';

  @override
  String get dietLowCarb => 'Low-carb';

  @override
  String get dietLowFat => 'Low-fat';

  @override
  String get dietMediterranean => 'Mediterranean';

  @override
  String get dietHalal => 'Halal';

  @override
  String get dietKosher => 'Kosher';

  @override
  String get allergyNuts => 'Nuts';

  @override
  String get allergyShellfish => 'Shellfish';

  @override
  String get allergyEggs => 'Eggs';

  @override
  String get allergySoy => 'Soy';

  @override
  String get allergyWheat => 'Wheat';

  @override
  String get allergyFish => 'Fish';

  @override
  String get allergyMilk => 'Milk';

  @override
  String get activitySedentary => 'Sedentary';

  @override
  String get activityLightlyActive => 'Lightly active';

  @override
  String get activityModeratelyActive => 'Moderately active';

  @override
  String get activityVeryActive => 'Very active';

  @override
  String get activityExtraActive => 'Extra active';

  @override
  String get goalLoseWeight => 'Lose weight';

  @override
  String get goalMaintain => 'Maintain weight';

  @override
  String get goalGainMuscle => 'Gain muscle';

  @override
  String get goalEatHealthier => 'Eat healthier';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountWarningTitle => 'This action is irreversible';

  @override
  String get deleteAccountWarningBody =>
      'These will be permanently deleted: your profile, food log history, weight history, photos, and chat history with the AI assistant. This cannot be undone.';

  @override
  String get deleteAccountAcknowledge =>
      'I understand that this action cannot be undone';

  @override
  String get deleteAccountAcknowledgeRequired =>
      'Please confirm that you understand the risk';

  @override
  String get deleteAccountCurrentPassword => 'Current password';

  @override
  String get deleteAccountCurrentPasswordRequired =>
      'Please enter your current password';

  @override
  String get deleteAccountHelperBeforeAck =>
      'First, confirm that you understand the risk';

  @override
  String get deleteAccountHelperAfterAck => 'Confirm your password to continue';

  @override
  String get deleteAccountConfirmButton => 'Delete account permanently';

  @override
  String get deleteAccountDialogTitle => 'Delete account for real?';

  @override
  String get deleteAccountDialogBody =>
      'This is your final warning. All your data will be deleted and cannot be recovered.';

  @override
  String get deleteAccountWrongPasswordMatch => 'Current password is incorrect';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordCurrent => 'Current password';

  @override
  String get changePasswordCurrentRequired =>
      'Please enter your current password';

  @override
  String get changePasswordNew => 'New password';

  @override
  String get changePasswordConfirm => 'Confirm new password';

  @override
  String get changePasswordConfirmRequired => 'Please confirm your password';

  @override
  String get changePasswordSave => 'Change password';

  @override
  String get trackerTitle => 'Tracker';

  @override
  String get trackerDateToday => 'Today';

  @override
  String get trackerDateYesterday => 'Yesterday';

  @override
  String get trackerDeleteRecordTitle => 'Delete record?';

  @override
  String trackerDeleteRecordBody(String name) {
    return '\"$name\" will be removed from today\'s log.';
  }

  @override
  String get trackerMealPickerTitle => 'Which meal does this belong to?';

  @override
  String get trackerCameraChoiceTitle => 'What are we photographing?';

  @override
  String get trackerCameraFood => 'Photograph food';

  @override
  String get trackerCameraFoodSubtitle =>
      'Identify macros and add an entry to the log';

  @override
  String get trackerCameraBeverage => 'Photograph beverage';

  @override
  String get trackerCameraBeverageSubtitle =>
      'Auto-add water and calories in one step';

  @override
  String get trackerEmptyLog => 'No entries yet';

  @override
  String trackerFoodSubtitle(
    String calories,
    String protein,
    String carbs,
    String fat,
  ) {
    return '$calories kcal • P/C/F $protein/$carbs/$fat g';
  }

  @override
  String get trackerCaloriesToday => 'Calories today';

  @override
  String get trackerCaloriesEaten => 'Calories consumed';

  @override
  String trackerCaloriesKcalOf(String target) {
    return ' / $target kcal';
  }

  @override
  String get trackerCaloriesKcalOnly => ' kcal';

  @override
  String get trackerWaterTitle => 'Water';

  @override
  String get trackerWaterGoalReached => 'Daily goal reached!';

  @override
  String trackerWaterPctOfGoal(String pct) {
    return '$pct% of daily goal';
  }

  @override
  String trackerWaterRemaining(String amount) {
    return '$amount remaining';
  }

  @override
  String get trackerWaterError => 'Could not save.';

  @override
  String get trackerWaterAddTitle => 'Add water';

  @override
  String get trackerWaterAddInstructions => 'Enter amount in litres (0.1–10 L)';

  @override
  String get trackerWaterLiters => 'Litres';

  @override
  String get trackerWaterHint => 'e.g. 0.5';

  @override
  String get trackerWaterRequired => 'Please enter the amount';

  @override
  String get trackerWaterMin => 'Minimum is 0.1 L';

  @override
  String get trackerWaterMax => 'Maximum is 10 L';

  @override
  String get trackerWeightCardTitle => 'Weight';

  @override
  String trackerWeightCardCurrent(String value) {
    return 'Current weight: $value kg';
  }

  @override
  String get trackerWeightCardAdd => 'Add weight';

  @override
  String get trackerDockCameraTooltip => 'Camera';

  @override
  String get trackerDockChatTooltip => 'Chat with NutriBot';

  @override
  String get trackerDockAddFoodTooltip => 'Add food';

  @override
  String get trackerDockProfileTooltip => 'Profile';

  @override
  String get trackerDockSettingsTooltip => 'Settings';

  @override
  String get trackerDatePrevTooltip => 'Previous day';

  @override
  String get trackerDateNextTooltip => 'Next day';

  @override
  String get trackerTooltipDelete => 'Delete';

  @override
  String get trackerTooltipRefine => 'Refine';

  @override
  String get trackerMealBreakfast => 'Breakfast';

  @override
  String get trackerMealLunch => 'Lunch';

  @override
  String get trackerMealDinner => 'Dinner';

  @override
  String get trackerMealSnack => 'Snack';

  @override
  String get trackerMealDrinks => 'Drinks';

  @override
  String get addFoodTitle => 'Add food';

  @override
  String get addFoodMealLabel => 'Meal';

  @override
  String get addFoodMealBreakfast => 'Breakfast';

  @override
  String get addFoodMealLunch => 'Lunch';

  @override
  String get addFoodMealDinner => 'Dinner';

  @override
  String get addFoodMealSnack => 'Snack';

  @override
  String get addFoodName => 'Name';

  @override
  String get addFoodQuantity => 'Quantity';

  @override
  String get addFoodUnit => 'Unit';

  @override
  String get addFoodUnitG => 'g';

  @override
  String get addFoodUnitMl => 'ml';

  @override
  String get addFoodUnitL => 'L';

  @override
  String get addFoodUnitPcs => 'pcs';

  @override
  String get addFoodCalories => 'Calories, kcal';

  @override
  String get addFoodProtein => 'Protein, g';

  @override
  String get addFoodCarbs => 'Carbs, g';

  @override
  String get addFoodFat => 'Fat, g';

  @override
  String get addFoodFiber => 'Fiber, g (optional)';

  @override
  String get addFoodButtonAdd => 'Add';

  @override
  String addFoodFieldRequired(String label) {
    return 'Please fill in \"$label\"';
  }

  @override
  String get addFoodEnterNumber => 'Please enter a number';

  @override
  String get addFoodMustBeNonNegative => 'Must be ≥ 0';

  @override
  String get addFoodMustBePositive => 'Must be > 0';

  @override
  String get photoFoodTitle => 'Photo of food';

  @override
  String get photoFoodCameraError =>
      'Could not open camera. Try picking from gallery instead.';

  @override
  String get photoFoodGalleryError => 'Could not open gallery.';

  @override
  String get photoFoodInstructions =>
      'Take a photo of your food or pick one from the gallery';

  @override
  String get photoFoodTakePhoto => 'Take photo';

  @override
  String get photoFoodPickGallery => 'Pick from gallery';

  @override
  String get photoFoodAnalyzing => 'Analyzing photo…';

  @override
  String get photoFoodErrorTitle =>
      'Could not recognize the dish in the photo. Try a clearer photo.';

  @override
  String get photoFoodAllergyWarningTitle => '⚠️ Possible allergy conflict';

  @override
  String photoFoodAllergyWarningBullet(String text) {
    return '•  $text';
  }

  @override
  String get photoFoodNoName => 'No name';

  @override
  String get photoFoodIngredientsTitle => 'Ingredients detected';

  @override
  String get photoBeverageTitle => 'Photo of beverage';

  @override
  String get photoBeverageInstructions =>
      'Take a photo of your drink or pick one from the gallery';

  @override
  String get photoBeverageAnalyzing => 'Analyzing photo…';

  @override
  String get photoBeverageSugar => 'Sugar';

  @override
  String photoBeverageMl(String value) {
    return '$value ml';
  }

  @override
  String get photoBeverageUnsure =>
      'Not sure about the identification — please review and confirm the details.';

  @override
  String get photoBeverageDescriptionMissing => '— no description';

  @override
  String get photoBeverageNameLabel => 'Beverage name';

  @override
  String get photoBeverageNameRequired => 'Please enter the name';

  @override
  String get photoBeverageVolumeLabel => 'Volume, ml';

  @override
  String get photoBeverageVolumeRequired => 'Please enter the volume';

  @override
  String get photoBeverageCaloriesLabel => 'Calories, kcal';

  @override
  String get photoBeverageMoreDetails =>
      'More details (protein, fat, carbs, sugar)';

  @override
  String get photoBeverageProteinLabel => 'Protein, g';

  @override
  String get photoBeverageCarbsLabel => 'Carbs, g';

  @override
  String get photoBeverageFatLabel => 'Fat, g';

  @override
  String get photoBeverageSugarLabel => 'Sugar, g';

  @override
  String get photoBeverageNonNegative => 'Must be ≥ 0';

  @override
  String get photoBeveragePositiveRequired => 'Volume must be greater than 0';

  @override
  String get photoBeverageConfirm => 'Confirm and save';

  @override
  String get photoBeverageSaved => 'Beverage saved';

  @override
  String get photoBeverageSaveError =>
      'Could not save the beverage. Try again.';

  @override
  String photoBeverageMismatchWarning(String name) {
    return 'This doesn\'t look like \"$name\" in the photo.';
  }

  @override
  String photoBeverageMismatchLooksLike(String suggestion) {
    return 'Looks more like: $suggestion.';
  }

  @override
  String get photoBeverageMismatchFix => 'Fix';

  @override
  String get photoBeverageMismatchProceed => 'Save anyway';

  @override
  String get photoBeverageVerifyFailed =>
      'Could not verify the photo match — saved without verification.';

  @override
  String get editFoodTitle => 'Refine description';

  @override
  String get editFoodHint =>
      'For example: this is brown rice, not white, and there is less oil';

  @override
  String get editFoodRequired =>
      'Please enter a description — it will be sent to the AI for re-estimation.';

  @override
  String get editFoodHelpText =>
      'Describe what is really in the dish — this will help the AI recalculate calories and macros more accurately. The image is not used.';

  @override
  String get editFoodRecalculate => 'Recalculate';

  @override
  String get editFoodAnalyzing => 'Analyzing description…';

  @override
  String get editFoodConfidenceHigh => 'High confidence';

  @override
  String get editFoodConfidenceMedium => 'Medium confidence';

  @override
  String get editFoodConfidenceLow => 'Low confidence';

  @override
  String get editFoodNoDescription => '— no description';

  @override
  String get editFoodRecalcBadge => 'Recalculated';

  @override
  String get trackerFoodProtein => 'Protein';

  @override
  String get trackerFoodCarbs => 'Carbs';

  @override
  String get trackerFoodFat => 'Fat';

  @override
  String get weightHistoryTitle => 'Weight history';

  @override
  String get weightHistoryAddTitle => 'Add weight entry';

  @override
  String get weightHistoryWeight => 'Weight, kg';

  @override
  String get weightHistoryWeightHint => 'e.g. 70.5';

  @override
  String get weightHistoryWeightRequired => 'Please enter a weight';

  @override
  String get weightHistoryWeightMustBePositive =>
      'Weight must be greater than 0';

  @override
  String get weightHistoryNote => 'Note (optional)';

  @override
  String get weightHistoryNoteHint => 'e.g. morning weigh-in';

  @override
  String get weightHistorySave => 'Save';

  @override
  String get weightHistoryErrorSave => 'Could not save.';

  @override
  String get weightHistoryDeleteTitle => 'Delete entry?';

  @override
  String get weightHistoryDeleteBody =>
      'This weight entry will be permanently deleted.';

  @override
  String get weightHistoryEmpty => 'No weight entries yet';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatClearHistoryTitle => 'Clear all chat history?';

  @override
  String get chatClearHistoryBody => 'This action cannot be undone.';

  @override
  String get chatClearHistoryConfirm => 'Clear';

  @override
  String get chatMenuTooltip => 'Menu';

  @override
  String get chatMenuClearHistory => 'Clear history';

  @override
  String get chatEmptyState =>
      'Ask me about nutrition, calorie goals, or foods!';

  @override
  String get chatInputHint => 'Ask about nutrition…';

  @override
  String get chatSendTooltip => 'Send';

  @override
  String get chatError => 'Something went wrong. Try again.';

  @override
  String get emailVerifyBannerMessage =>
      'Verify your email so you don\'t lose access to your account.';

  @override
  String get emailVerifyBannerAction => 'Verify';

  @override
  String get emailVerifyBannerDismissTooltip => 'Dismiss';

  @override
  String get apiEnvCardTitle => 'API environment (dev only)';

  @override
  String get apiEnvCardCurrentUrl => 'Current URL';

  @override
  String apiEnvCardBaseUrlApplied(String url) {
    return 'Base URL: $url';
  }

  @override
  String get apiEnvCardBaseUrlAppliedBody =>
      'New requests will use it. Pull-to-refresh or navigate to another section to update already-loaded screens.';

  @override
  String get apiEnvCardPresets => 'Quick presets';

  @override
  String get apiEnvCardPresetIos => 'iOS Simulator (localhost)';

  @override
  String get apiEnvCardPresetAndroid => 'Android Emulator';

  @override
  String get apiEnvCardCustomUrl =>
      'Custom URL (e.g. for a device on the local network)';

  @override
  String get apiEnvCardBaseUrlField => 'Base URL';

  @override
  String get apiEnvCardBaseUrlRequired => 'Please enter a URL';

  @override
  String get apiEnvCardBaseUrlInvalid =>
      'URL must start with http:// or https://';

  @override
  String get apiEnvCardApply => 'Apply';

  @override
  String get apiEnvCardReset => 'Reset to default';

  @override
  String get tagInputDefaultHint => 'Type and press Enter…';

  @override
  String get userFacingErrorServerEmpty => 'Server returned an empty response.';

  @override
  String get userFacingErrorFoodPhotoRecognize =>
      'Could not recognize the dish in the photo. Try a clearer photo.';

  @override
  String get userFacingErrorFoodReanalyze =>
      'Could not analyze the description. Try rephrasing.';

  @override
  String get userFacingErrorBeverageRecognize =>
      'Could not recognize the beverage. Try a different photo.';

  @override
  String get userFacingErrorPhotoProcess =>
      'Could not process the photo. Try again.';

  @override
  String get userFacingErrorDescriptionProcess =>
      'Could not process the description. Try again.';

  @override
  String get userFacingErrorUploadPhoto =>
      'Could not upload photo. Check file size (max. 5 MB).';

  @override
  String get userFacingErrorPhotoUrl => 'Server did not return a photo URL.';

  @override
  String onboardingRequiredField(String label) {
    return 'Please fill in «$label»';
  }

  @override
  String get homeLoading => 'Loading…';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name!';
  }

  @override
  String get homeTrackerPreview => 'Here will be the nutrition tracker.';

  @override
  String get homeLogout => 'Log out';

  @override
  String get photoBeverageCameraError =>
      'Could not open camera. Try picking from gallery instead.';

  @override
  String get photoBeverageGalleryError => 'Could not open gallery.';

  @override
  String get photoBeverageTakePhoto => 'Take photo';

  @override
  String get photoBeveragePickGallery => 'Pick from gallery';

  @override
  String trackerWaterProgress(Object current, Object goal) {
    return '$current / $goal';
  }

  @override
  String get photoFoodConfidenceHigh => 'High confidence';

  @override
  String get photoFoodConfidenceMedium => 'Medium confidence';

  @override
  String get photoFoodConfidenceLow => 'Low confidence';

  @override
  String get photoBeverageConfidenceHigh => 'High confidence';

  @override
  String get photoBeverageConfidenceMedium => 'Medium confidence';

  @override
  String get photoBeverageConfidenceLow => 'Low confidence';

  @override
  String get macroProteinShort => 'P';

  @override
  String get macroCarbsShort => 'C';

  @override
  String get macroFatShort => 'F';

  @override
  String get macroSugarShort => 'S';

  @override
  String get unitGramsShort => 'g';

  @override
  String get unitKgShort => 'kg';

  @override
  String get unitKcalShort => 'kcal';

  @override
  String get weightHistoryLatestMissing => 'No data yet';

  @override
  String weightHistoryTarget(String value) {
    return 'Goal: $value kg';
  }

  @override
  String weightHistoryRemaining(String value) {
    return 'Remaining: $value kg';
  }

  @override
  String get weightHistoryChartGoalLabel => 'Goal';

  @override
  String get weightHistoryMustBePositive => 'Must be > 0';

  @override
  String get weightHistoryTooLarge => 'Value too large';
}
