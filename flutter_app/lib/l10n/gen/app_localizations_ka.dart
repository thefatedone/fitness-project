// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Georgian (`ka`).
class AppLocalizationsKa extends AppLocalizations {
  AppLocalizationsKa([String locale = 'ka']) : super(locale);

  @override
  String get appName => 'NutriMind';

  @override
  String get commonCancel => 'გაუქმება';

  @override
  String get commonSave => 'შენახვა';

  @override
  String get commonDelete => 'წაშლა';

  @override
  String get commonDone => 'მზადია';

  @override
  String get commonYesDelete => 'დიახ, წაშლა';

  @override
  String get commonTryAgain => 'თავიდან ცდა';

  @override
  String get commonConfirm => 'დადასტურება';

  @override
  String get commonClose => 'დახურვა';

  @override
  String get commonError =>
      'რაღაც შეცდომით წარიდგა. შეამოწმე კავშირი და თავიდან სცადე.';

  @override
  String get commonErrorShort => 'რაღაც შეცდომით წარიდგა.';

  @override
  String get commonErrorWithRetry => 'რაღაც შეცდომით წარიდგა. თავიდან სცადე.';

  @override
  String get themeLight => 'ღია';

  @override
  String get themeDark => 'მუქი';

  @override
  String get themeSystem => 'სისტემური';

  @override
  String get themeDescriptionLight => 'ყოველთვის ღია თემა.';

  @override
  String get themeDescriptionDark => 'ყოველთვის მუქი თემა.';

  @override
  String get themeDescriptionSystem => 'თემა მიჰყვება სისტემის პარამეტტრებს.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGeorgian => 'ქართული';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageSectionLabel => 'ენა';

  @override
  String get languageFieldTheme => 'თემა';

  @override
  String get authLoginTitle => 'NutriMind';

  @override
  String get authLoginSubtitle => 'კეთილი იყო მობრძანება';

  @override
  String get authEmailLabel => 'ელ.ფოსტა';

  @override
  String get authEmailRequired => 'შეიყვანე ელ.ფოსტა';

  @override
  String get authEmailInvalid => 'ეს ელ.ფოსტა არ გამოიყურება სწორად';

  @override
  String get authPasswordLabel => 'პაროლი';

  @override
  String get authPasswordRequired => 'შეიყვანე პაროლი';

  @override
  String get authPasswordHelper => 'მინ. 8 სიმბოლო, ერთი დიდი ასო, ერთი ციფრა';

  @override
  String get authLoginButton => 'შესვლა';

  @override
  String get authForgotPassword => 'დაგავიწყდა პაროლი?';

  @override
  String get authNoAccountRegister => 'არ გაქვს ანგარიში? დარეგისტრირდი';

  @override
  String get authServerDebugLink => 'სერვერის პარამეტტრები (debug)';

  @override
  String get authSessionExpired => 'სესია ამოიწურა. გთხოვ, თავიდან შედი.';

  @override
  String get authRegisterTitle => 'რეგისტტრაცია';

  @override
  String get authRegisterName => 'სრული სახელი';

  @override
  String get authRegisterNameRequired => 'შეიყვანე სახელი';

  @override
  String get authRegisterPassword => 'პაროლი';

  @override
  String get authRegisterCreate => 'ანგარიშის შექმნა';

  @override
  String get authForgotTitle => 'პაროლის აღდგენა';

  @override
  String get authForgotInstructions =>
      'შეიყვანე ანგარიშთან დაკავშირებული ელ.ფოსტა — გამოგიგზავნებთ კოდს პაროლის გადასაყენებლად.';

  @override
  String get authForgotSendCode => 'კოდის გაგზავნა';

  @override
  String get authCodeTitle => 'შეიყვანე კოდი';

  @override
  String authCodeInstructions(String email) {
    return 'კოდი გამოგზავნეთ მისამართზე $email';
  }

  @override
  String get authCodeField => 'კოდი';

  @override
  String get authCodeRequired => 'კოდი უნდა იყოს 6 ციფრისგან შემდგარი';

  @override
  String get authCodeConfirm => 'დადასტურება';

  @override
  String get authCodeResend => 'კოდის თავიდან გამოგზავნა';

  @override
  String get authResetTitle => 'ახალი პაროლი';

  @override
  String authResetInstructions(String email) {
    return 'შეიყვანე ახალი პაროლი მისამართისთვის $email';
  }

  @override
  String get authResetNewPassword => 'ახალი პაროლი';

  @override
  String get authResetConfirmPassword => 'გაიმეორე პაროლი';

  @override
  String get authResetConfirmRequired => 'დაადასტურე პაროლი';

  @override
  String get authResetMismatch => 'პაროლები არ ემთხვევა';

  @override
  String get authResetSave => 'ახალი პაროლის შენახვა';

  @override
  String get authResetSuccess => 'პაროლი შეიცვალა. ახლა შეგიძლია შეხვიდე.';

  @override
  String get authEmailVerifyTitle => 'ელ.ფოსტის დადასტურება';

  @override
  String authEmailVerifyInstructions(String email) {
    return 'დადასტურების კოდს გამოვუგზავნით მისამართზე $email';
  }

  @override
  String get authEmailVerifyEnterCode => 'შეიყვანე წერილში მოსალოდნე კოდი';

  @override
  String get authEmailVerifySendCode => 'კოდის გაგზავნა';

  @override
  String get authEmailVerifyResend => 'კოდის თავიდან გამოგზავნა';

  @override
  String get authPasswordMinLength =>
      'პაროლი უნდა შედგებოდეს მინიმუმ 8 სიმბოლოსგან';

  @override
  String get authPasswordNeedUpper => 'პაროლის პირველი ასო უნდა იყოს დიდი';

  @override
  String get authPasswordNeedDigit =>
      'პაროლი უნდა შეიცავდეს მინიმუმ ერთ ციფრას';

  @override
  String get authServerUnreachable =>
      'სერვერი არ პასუხობს. შეამოწმე კავშირი და თავიდან სცადე.';

  @override
  String get authNoConnection =>
      'სერვერთან კავშირი ვერ დამყარდა. შეამოწმე ინტერნეტი.';

  @override
  String get authSecureConnectionFailed =>
      'უსაფრთხო კავშირი სერვერთან ვერ დამყარდა.';

  @override
  String get authRequestCancelled => 'მოთხოვნა გაუქმდა.';

  @override
  String get authEmptyResponse => 'სერვერმა ცარიელი პასუხი დააბრუნა.';

  @override
  String get authNoAuthToken => 'სერვერმა ავთენტიფკატორი არ გასცა.';

  @override
  String get authConfirmationMissing => 'სერვერმა დადასტურება არ დააბრუნა.';

  @override
  String get onboardingStep1Title => 'ნაბიჯი 1 / 4 — ანგარიში';

  @override
  String get onboardingStep1Subtitle =>
      'ჯერ შევიკრიბოთ სახელი, ელ.ფოსტა და პაროლი. დანარჩენი ნაბიჯები შემდეგ.';

  @override
  String get onboardingStep2Title => 'ნაბიჯი 2 / 4 — პირადი მონაცემები';

  @override
  String get onboardingStep2Subtitle => 'დაბადების თარიღი და სქესი.';

  @override
  String get onboardingStep3Title => 'ნაბიჯი 3 / 4 — სხეული და მიზანი';

  @override
  String get onboardingStep3Subtitle =>
      'სიმაღლე, წონა, სამიზნო წონა, აქტივობის დონე და მიზანი.';

  @override
  String get onboardingStep4Title => 'ნაბიჯი 4 / 4 — კვება და ალერგიები';

  @override
  String get onboardingStep4Subtitle =>
      'თითქმის მზად ხარ! ეს ველები არასავალდებელია — შეგიძლია მოგვიანებით შეავსო პროფილის განყოფილებაში.';

  @override
  String get onboardingBirthday => 'დაბადების თარიღი';

  @override
  String get onboardingBirthdayRequired => 'შეიყვანე დაბადების თარიღი';

  @override
  String get onboardingBirthdayNotSet => 'არ არის მითითებული';

  @override
  String get onboardingGender => 'სქესი';

  @override
  String get onboardingGenderMale => 'მამრობითი';

  @override
  String get onboardingGenderFemale => 'მდედრობითი';

  @override
  String get onboardingGenderOther => 'არ მინდა მითითება';

  @override
  String get onboardingGenderRequired => 'აირჩიე ვარიანტი';

  @override
  String get onboardingDietaryPreferences =>
      'კვების უპირატესობები (არასავალდებელია)';

  @override
  String get onboardingDietaryHint => 'მაგალითად, ვეგეტარიანელი, კეტტო…';

  @override
  String get onboardingAllergies =>
      'ალერგიები და შეუთავსებლობა (არასავალდებელია)';

  @override
  String get onboardingAllergiesHint => 'მაგალითად, თხილი, რძე…';

  @override
  String get onboardingHeight => 'სიმაღლე, სმ';

  @override
  String get onboardingHeightHint => 'მაგ. 175';

  @override
  String get onboardingCurrentWeight => 'მიმდინარე წონა, კგ';

  @override
  String get onboardingCurrentWeightHint => 'მაგ. 70.5';

  @override
  String get onboardingTargetWeight => 'სამიზნო წონა, კგ';

  @override
  String get onboardingTargetWeightHint => 'მაგ. 65';

  @override
  String get onboardingActivityLevel => 'აქტივობის დონე';

  @override
  String get onboardingActivityLevelRequired => 'აირჩიე აქტივობის დონე';

  @override
  String get onboardingPrimaryGoal => 'მთავარი მიზანი';

  @override
  String get onboardingPrimaryGoalRequired => 'აირჩიე მთავარი მიზანი';

  @override
  String onboardingPaceLabel(String value) {
    return 'ტემპი: $value კგ/კვირაში';
  }

  @override
  String onboardingPaceChipLabel(String value) {
    return '$value კგ/კვირა';
  }

  @override
  String get onboardingRequired => 'შეავსე';

  @override
  String get onboardingEnterNumber => 'შეიყვანე რიცხვი';

  @override
  String get onboardingMustBePositive => 'უნდა იყოს 0-ზე მეტი';

  @override
  String get onboardingBack => 'უკან';

  @override
  String get onboardingNext => 'შემდეგ';

  @override
  String get onboardingFinish => 'რეგისტრაციის დასრულება';

  @override
  String get onboardingGenericError => 'რეგისტრაცია ვერ დასრულდა.';

  @override
  String get onboardingPartialSaveWarning =>
      'პროფილი შეიქმნა, მაგრამ ზოგიერი მონაცემი არ შენახულა — შეავსე მოგვიანებით პროფილის განყოფილებაში.';

  @override
  String get settingsTitle => 'პარამეტტრები';

  @override
  String get settingsSectionAppearance => 'გარეგნობა';

  @override
  String get settingsSectionTheme => 'თემა';

  @override
  String get settingsSectionAccount => 'ანგარიში';

  @override
  String get settingsSectionAbout => 'პროგრამის შესახებ';

  @override
  String get settingsSectionApiEnvironmentDebug => 'API გარემო (მხოლოდ დევ)';

  @override
  String get settingsChangePassword => 'პაროლის შეცვლა';

  @override
  String get settingsDeleteAccount => 'ანგარიშის წაშლა';

  @override
  String get settingsVersion => 'ვერსია';

  @override
  String get settingsLogout => 'სისტემიდან გასვლა';

  @override
  String get profileTitle => 'პროფილი';

  @override
  String get profileSave => 'ცვლილებების შენახვა';

  @override
  String get profileUpdated => 'პროფილი განახლდა';

  @override
  String get profileUpdateError => 'ვერ შენახდა.';

  @override
  String get profileSavePhotoTitle => 'საიდან მივიღოთ ფოტო?';

  @override
  String get profilePhotoCamera => 'გადაღება';

  @override
  String get profilePhotoGallery => 'არჩევა გალერეიდან';

  @override
  String get profilePhotoCropTitle => 'ფოტოს მოჭრა';

  @override
  String get profilePhotoCropError =>
      'ფოტოს მოჭრა ვერ მოხერხდა. თავიდან სცადე.';

  @override
  String get profilePhotoReadError => 'მოჭრილი ფოტოს წაკითხვა ვერ მოხერხდა.';

  @override
  String get profilePhotoTooLarge => 'ფოტო ძალიან დიდია, სცადე სხვა';

  @override
  String get profilePhotoUpdated => 'ფოტო განახლდა';

  @override
  String get profileCameraError =>
      'კამერის გახსნა ვერ მოხერხდა. სცადე გალერეიდან არჩევა.';

  @override
  String get profileGalleryError => 'გალერეის გახსნა ვერ მოხერხდა.';

  @override
  String get profileSectionBasic => 'ძირითადი';

  @override
  String get profileSectionBody => 'სხეულის პარამეტტრები';

  @override
  String get profileSectionGoalActivity => 'მიზანი და აქტივობა';

  @override
  String get profileFieldName => 'სახელი';

  @override
  String get profileFieldBirthday => 'დაბადების თარიღი';

  @override
  String get profileFieldGender => 'სქესი';

  @override
  String get profileMetricHeight => 'სიმაღლე, სმ';

  @override
  String get profileMetricHeightHint => 'მაგ. 175';

  @override
  String get profileMetricCurrentWeight => 'მიმდინარე წონა, კგ';

  @override
  String get profileMetricCurrentWeightHint => 'მაგ. 70.5';

  @override
  String get profileMetricTargetWeight => 'სამიზნო წონა, კგ';

  @override
  String get profileMetricTargetWeightHint => 'მაგ. 65';

  @override
  String profileBmiLabel(String label) {
    return 'BMI: $label';
  }

  @override
  String get profileViewWeightHistory => 'წონის ისტორიის ნახვა';

  @override
  String get profilePrimaryGoal => 'მთავარი მიზანი';

  @override
  String get profileActivityLevel => 'აქტივობის დონე';

  @override
  String profilePace(String value) {
    return 'წონის კლების ტემპი: $value კგ/კვირაში';
  }

  @override
  String profilePaceChip(String value) {
    return '$value კგ/კვირა';
  }

  @override
  String get profileDietaryPreferences => 'კვების უპირატესობები';

  @override
  String get profileDietaryHint => 'მაგ. ვეგეტარიანელი…';

  @override
  String get profileAllergies => 'ალერგიები და შეუთავსებლობა';

  @override
  String get profileAllergiesAiHint =>
      'AI ფოტო-ამოცნობა იყენებს კონფლიქტების გაფრთხილებლად.';

  @override
  String get profileAllergiesHint => 'მაგ. თხილი…';

  @override
  String get profileBmiUnderweight => 'წონის დეფიციდი';

  @override
  String get profileBmiNormal => 'ნორმა';

  @override
  String get profileBmiOverweight => 'ჭარბი წონა';

  @override
  String get profileBmiObese => 'სიმსუქნე';

  @override
  String get dietVegetarian => 'ვეგეტარიანელი';

  @override
  String get dietVegan => 'ვეგანი';

  @override
  String get dietKeto => 'კეტტო';

  @override
  String get dietPaleo => 'პალეო';

  @override
  String get dietLowCarb => 'ნახშირწყლის დაბალი';

  @override
  String get dietLowFat => 'ცხიმის დაბალი';

  @override
  String get dietMediterranean => 'ხმელთაშუა ზღვის';

  @override
  String get dietHalal => 'ჰალალი';

  @override
  String get dietKosher => 'კოშერული';

  @override
  String get allergyNuts => 'თხილი';

  @override
  String get allergyShellfish => 'ზღვის პროდუქტტლი';

  @override
  String get allergyEggs => 'კვერცხი';

  @override
  String get allergySoy => 'სოია';

  @override
  String get allergyWheat => 'ხორბალი';

  @override
  String get allergyFish => 'თევზი';

  @override
  String get allergyMilk => 'რძე';

  @override
  String get activitySedentary => 'უმოძრაო';

  @override
  String get activityLightlyActive => 'მცირე აქტივობით';

  @override
  String get activityModeratelyActive => 'ზომიერი აქტივობით';

  @override
  String get activityVeryActive => 'მაღალი აქტივობით';

  @override
  String get activityExtraActive => 'ძალიან მაღალი აქტივობით';

  @override
  String get goalLoseWeight => 'წონის კლება';

  @override
  String get goalMaintain => 'წონის შენარჩუნება';

  @override
  String get goalGainMuscle => 'კუნთოვანი მასის მომატება';

  @override
  String get goalEatHealthier => 'ჯანსაღი კვება';

  @override
  String get deleteAccountTitle => 'ანგარიშის წაშლა';

  @override
  String get deleteAccountWarningTitle => 'ეს მოქმედება შეუქცევადია';

  @override
  String get deleteAccountWarningBody =>
      'სამუდამტანოდ წაიშლება: შენი პროფილი, კვების ისტორია, წონის ისტორია, ფოტოები და AI ასისტენტთან საუბრების ისტორია. ეს ვერ გაუქმდება.';

  @override
  String get deleteAccountAcknowledge =>
      'მესმის, რომ ეს მოქმედება ვერ გაუქმდება';

  @override
  String get deleteAccountAcknowledgeRequired => 'დაადასტურე, რომ გესმის რისკი';

  @override
  String get deleteAccountCurrentPassword => 'მიმდინარე პაროლი';

  @override
  String get deleteAccountCurrentPasswordRequired =>
      'შეიყვანე მიმდინარე პაროლი';

  @override
  String get deleteAccountHelperBeforeAck => 'ჯერ დაადასტურე, რომ გესმის რისკი';

  @override
  String get deleteAccountHelperAfterAck => 'დაადასტურე პაროლი გასაგრძელებლად';

  @override
  String get deleteAccountConfirmButton => 'წაშალე ანგარიში სამუდამტანოდ';

  @override
  String get deleteAccountDialogTitle => 'ნამდვილებით წაშლა?';

  @override
  String get deleteAccountDialogBody =>
      'ეს ბოლო გაფრთხილებაა. ყველა მონაცემი წაიშლება და ვერ აღდგება.';

  @override
  String get deleteAccountWrongPasswordMatch => 'მიმდინარე პაროლი არასწორია';

  @override
  String get changePasswordTitle => 'პაროლის შეცვლა';

  @override
  String get changePasswordCurrent => 'მიმდინარე პაროლი';

  @override
  String get changePasswordCurrentRequired => 'შეიყვანე მიმდინარე პაროლი';

  @override
  String get changePasswordNew => 'ახალი პაროლი';

  @override
  String get changePasswordConfirm => 'დაადასტურე ახალი პაროლი';

  @override
  String get changePasswordConfirmRequired => 'დაადასტურე პაროლი';

  @override
  String get changePasswordSave => 'პაროლის შეცვლა';

  @override
  String get trackerTitle => 'თრეკერი';

  @override
  String get trackerDateToday => 'დღეს';

  @override
  String get trackerDateYesterday => 'გუშინ';

  @override
  String get trackerDeleteRecordTitle => 'წავშალოთ ჩანაწერი?';

  @override
  String trackerDeleteRecordBody(String name) {
    return '„$name“ წაიშლება დღევნდელი ჟურნალიდან.';
  }

  @override
  String get trackerMealPickerTitle => 'რომელ კვებას მიაკუთვნოთ?';

  @override
  String get trackerCameraChoiceTitle => 'რას ვუღებთ ფოტოს?';

  @override
  String get trackerCameraFood => 'საჭმლის გადაღება';

  @override
  String get trackerCameraFoodSubtitle =>
      'კბზ-ცხ-ცხ-ც გამოთვლა და ჩანაწერი ჟურნალში';

  @override
  String get trackerCameraBeverage => 'სასმელის გადაღება';

  @override
  String get trackerCameraBeverageSubtitle =>
      'წყალსა და კალორიებს ავტომატურად დამატება ერთ ნაბიჯში';

  @override
  String get trackerEmptyLog => 'ჩანაწერები ჯერ არ არის';

  @override
  String trackerFoodSubtitle(
    String calories,
    String protein,
    String carbs,
    String fat,
  ) {
    return '$calories კკალ • ც-ნ-ც $protein/$carbs/$fat გ';
  }

  @override
  String get trackerCaloriesToday => 'დღევნდელი კალორიები';

  @override
  String get trackerCaloriesEaten => 'მიღებული კალორიები';

  @override
  String trackerCaloriesKcalOf(String target) {
    return ' / $target კკალ';
  }

  @override
  String get trackerCaloriesKcalOnly => ' კკალ';

  @override
  String get trackerWaterTitle => 'წყალი';

  @override
  String get trackerWaterGoalReached => 'დღევანდელი მიზანი მიღწეულია!';

  @override
  String trackerWaterPctOfGoal(String pct) {
    return 'დღევანდელი მიზნის $pct%';
  }

  @override
  String trackerWaterRemaining(String amount) {
    return 'დარჩა $amount';
  }

  @override
  String get trackerWaterError => 'ვერ შენახდა.';

  @override
  String get trackerWaterAddTitle => 'წყლის დამატება';

  @override
  String get trackerWaterAddInstructions =>
      'შეიყვანე რაოდენობა ლიტტრებში (0.1–10 ლ)';

  @override
  String get trackerWaterLiters => 'ლიტტრები';

  @override
  String get trackerWaterHint => 'მაგ. 0.5';

  @override
  String get trackerWaterRequired => 'შეიყვანე რაოდენობა';

  @override
  String get trackerWaterMin => 'მინიმუმ 0.1 ლ';

  @override
  String get trackerWaterMax => 'მაქსიმუმ 10 ლ';

  @override
  String get trackerWeightCardTitle => 'წონა';

  @override
  String trackerWeightCardCurrent(String value) {
    return 'მიმდინარე წონა: $value კგ';
  }

  @override
  String get trackerWeightCardAdd => 'წონის დამატება';

  @override
  String get trackerDockCameraTooltip => 'კამერა';

  @override
  String get trackerDockChatTooltip => 'NutriBot-თან ჩატი';

  @override
  String get trackerDockAddFoodTooltip => 'საჭმლის დამატება';

  @override
  String get trackerDockProfileTooltip => 'პროფილი';

  @override
  String get trackerDockSettingsTooltip => 'პარამეტტრები';

  @override
  String get trackerDatePrevTooltip => 'წინა დღე';

  @override
  String get trackerDateNextTooltip => 'შემდეგი დღე';

  @override
  String get trackerTooltipDelete => 'წაშლა';

  @override
  String get trackerTooltipRefine => 'დაზუსტება';

  @override
  String get trackerMealBreakfast => 'საუზმე';

  @override
  String get trackerMealLunch => 'სადილე';

  @override
  String get trackerMealDinner => 'ვახშამი';

  @override
  String get trackerMealSnack => 'საჭმელი';

  @override
  String get trackerMealDrinks => 'სასმელები';

  @override
  String get addFoodTitle => 'საჭმლის დამატება';

  @override
  String get addFoodMealLabel => 'კვება';

  @override
  String get addFoodMealBreakfast => 'საუზმე';

  @override
  String get addFoodMealLunch => 'სადილე';

  @override
  String get addFoodMealDinner => 'ვახშამი';

  @override
  String get addFoodMealSnack => 'საჭმელი';

  @override
  String get addFoodName => 'სახელი';

  @override
  String get addFoodQuantity => 'რაოდენობა';

  @override
  String get addFoodUnit => 'ერთ.';

  @override
  String get addFoodUnitG => 'გ';

  @override
  String get addFoodUnitMl => 'მლ';

  @override
  String get addFoodUnitPcs => 'ცალი';

  @override
  String get addFoodCalories => 'კალორიები, კკალ';

  @override
  String get addFoodProtein => 'ცილები, გ';

  @override
  String get addFoodCarbs => 'ნახშირწყლები, გ';

  @override
  String get addFoodFat => 'ცხიმები, გ';

  @override
  String get addFoodFiber => 'ბოჭკოვი, გ (არასავალდებელია)';

  @override
  String get addFoodButtonAdd => 'დამატება';

  @override
  String addFoodFieldRequired(String label) {
    return 'შეავსე «$label»';
  }

  @override
  String get addFoodEnterNumber => 'შეიყვანე რიცხვი';

  @override
  String get addFoodMustBeNonNegative => 'უნდა იყოს ≥ 0';

  @override
  String get addFoodMustBePositive => 'უნდა იყოს > 0';

  @override
  String get photoFoodTitle => 'საჭმლის ფოტო';

  @override
  String get photoFoodCameraError =>
      'კამერის გახსნა ვერ მოხერხდა. სცადე გალერეიდან არჩევა.';

  @override
  String get photoFoodGalleryError => 'გალერეის გახსნა ვერ მოხერხდა.';

  @override
  String get photoFoodInstructions =>
      'გადაიღე საჭმელი ან აირჩიე ფოტო გალერეიდან';

  @override
  String get photoFoodTakePhoto => 'ფოტოს გადაღება';

  @override
  String get photoFoodPickGallery => 'არჩევა გალერეიდან';

  @override
  String get photoFoodAnalyzing => 'ფოტოს ანალიზი…';

  @override
  String get photoFoodErrorTitle =>
      'კერძელობის ფოტოზე ამოცნობა ვერ მოხერხდა. სცადე უფრო ნათელი ფოტო.';

  @override
  String get photoFoodAllergyWarningTitle =>
      '⚠️ შესაძლო შეუთავსებლობა ალერგიასთან';

  @override
  String photoFoodAllergyWarningBullet(String text) {
    return '•  $text';
  }

  @override
  String get photoFoodNoName => 'უსახელო';

  @override
  String get photoFoodIngredientsTitle => 'რა იქნა ამოცნობილი';

  @override
  String get photoBeverageTitle => 'სასმელის ფოტო';

  @override
  String get photoBeverageInstructions =>
      'გადაიღე სასმელი ან აირჩიე ფოტო გალერეიდან';

  @override
  String get photoBeverageAnalyzing => 'ფოტოს ანალიზი…';

  @override
  String get photoBeverageSugar => 'შაქარი';

  @override
  String photoBeverageMl(String value) {
    return '$value მლ';
  }

  @override
  String get photoBeverageUnsure =>
      'ამოცნობაში დარწმუნებული არ ვარ — შეამოწმე და დაადასტურე მონაცემები.';

  @override
  String get photoBeverageDescriptionMissing => '— აღწერა არ არის';

  @override
  String get photoBeverageNameLabel => 'სასმელის სახელი';

  @override
  String get photoBeverageNameRequired => 'შეიყვანე სახელი';

  @override
  String get photoBeverageVolumeLabel => 'მოცულობა, მლ';

  @override
  String get photoBeverageVolumeRequired => 'შეიყვანე მოცულობა';

  @override
  String get photoBeverageCaloriesLabel => 'კალორიები, კკალ';

  @override
  String get photoBeverageMoreDetails =>
      'მეტი დეტალი (ცილები, ცხიმები, ნახშირწყლები, შაქარი)';

  @override
  String get photoBeverageProteinLabel => 'ცილები, გ';

  @override
  String get photoBeverageCarbsLabel => 'ნახშირწყლები, გ';

  @override
  String get photoBeverageFatLabel => 'ცხიმები, გ';

  @override
  String get photoBeverageSugarLabel => 'შაქარი, გ';

  @override
  String get photoBeverageNonNegative => 'არ შეიძლება უარყოფითი იყოს';

  @override
  String get photoBeveragePositiveRequired => 'მოცულობა უნდა იყოს 0-ზე მეტი';

  @override
  String get photoBeverageConfirm => 'დადასტურება და შენახვა';

  @override
  String get photoBeverageSaved => 'სასმელი შენახულია';

  @override
  String get photoBeverageSaveError =>
      'სასმელის შენახვა ვერ მოხერხდა. თავიდან სცადე.';

  @override
  String photoBeverageMismatchWarning(String name) {
    return 'ფოტოს მიხედვით ეს „$name“ არ ჰგავს.';
  }

  @override
  String photoBeverageMismatchLooksLike(String suggestion) {
    return 'უფრო ჰგავს: $suggestion.';
  }

  @override
  String get photoBeverageMismatchFix => 'შესწორება';

  @override
  String get photoBeverageMismatchProceed => 'მაინც შენახვა';

  @override
  String get photoBeverageVerifyFailed =>
      'ფოტოს შესაბამისობა ვერ შემოწმდა — შენახულია გადამოწმების გარეშე.';

  @override
  String get editFoodTitle => 'აღწერის დაზუსტება';

  @override
  String get editFoodHint =>
      'მაგალითად: სინამდვილეში ეს ყავისფერი ბრინჯია, არა თეთრი, და ზეთი ნაკლები იყო';

  @override
  String get editFoodRequired =>
      'შეიყვანე აღწერა — ის AI-ს გადაეგზავნება ხელმეოდან.';

  @override
  String get editFoodHelpText =>
      'აღწერე, რა არის ნამდვილევლ კერძეში — ეს AI-ს დაეხმარება უფრო ზუსტად გადათვალოს კალორიები და მაკროელემენტები. ფოტო არ გამოიყენება.';

  @override
  String get editFoodRecalculate => 'ხელახლა გამოთვლა';

  @override
  String get editFoodAnalyzing => 'აღწერის ანალიზი…';

  @override
  String get editFoodConfidenceHigh => 'მაღალი სიზუსტე';

  @override
  String get editFoodConfidenceMedium => 'საშუალო სიზუსტე';

  @override
  String get editFoodConfidenceLow => 'დაბალი სიზუსტე';

  @override
  String get editFoodNoDescription => '— აღწერა არ არის';

  @override
  String get editFoodRecalcBadge => 'გადათვალა';

  @override
  String get trackerFoodProtein => 'ცილები';

  @override
  String get trackerFoodCarbs => 'ნახშირწყლები';

  @override
  String get trackerFoodFat => 'ცხიმები';

  @override
  String get weightHistoryTitle => 'წონის ისტორია';

  @override
  String get weightHistoryAddTitle => 'წონის ჩანაწერის დამატება';

  @override
  String get weightHistoryWeight => 'წონა, კგ';

  @override
  String get weightHistoryWeightHint => 'მაგ. 70.5';

  @override
  String get weightHistoryWeightRequired => 'შეიყვანე წონა';

  @override
  String get weightHistoryWeightMustBePositive => 'წონა უნდა იყოს 0-ზე მეტი';

  @override
  String get weightHistoryNote => 'შენიშვნა (არასავალდებელია)';

  @override
  String get weightHistoryNoteHint => 'მაგ. საღამოს გაზომება';

  @override
  String get weightHistorySave => 'შენახვა';

  @override
  String get weightHistoryErrorSave => 'ვერ შენახდა.';

  @override
  String get weightHistoryDeleteTitle => 'ჩანაწერის წაშლა?';

  @override
  String get weightHistoryDeleteBody =>
      'ეს წონის ჩანაწერი სამუდამტანოდ წაიშლება.';

  @override
  String get weightHistoryEmpty => 'წონის ჩანაწერები ჯერ არ არის';

  @override
  String get chatTitle => 'ჩატი';

  @override
  String get chatClearHistoryTitle => 'წაშალოთ ჩატის მთელი ისტორია?';

  @override
  String get chatClearHistoryBody => 'ეს მოქმედება შეუქცევადია.';

  @override
  String get chatClearHistoryConfirm => 'წაშლა';

  @override
  String get chatMenuTooltip => 'მენიუ';

  @override
  String get chatMenuClearHistory => 'ისტორიის გასუფთავება';

  @override
  String get chatEmptyState =>
      'მკითხე კვებაზე, კალორიების მიზნებზე ან პროდუქტტლზე!';

  @override
  String get chatInputHint => 'კვების შესახებ მკითხე…';

  @override
  String get chatSendTooltip => 'გაგზავნა';

  @override
  String get chatError => 'რაღაც შეცდომით წარიდგა. თავიდან სცადე.';

  @override
  String get emailVerifyBannerMessage =>
      'დაადასტურე ელ.ფოსტა, რომ ანგარიშზე წვდომა არ დაკარგო.';

  @override
  String get emailVerifyBannerAction => 'დადასტურება';

  @override
  String get emailVerifyBannerDismissTooltip => 'დამალვა';

  @override
  String get apiEnvCardTitle => 'API გარემო (მხოლოდ დევ)';

  @override
  String get apiEnvCardCurrentUrl => 'მიმდინარე URL';

  @override
  String apiEnvCardBaseUrlApplied(String url) {
    return 'საბაზისო URL: $url';
  }

  @override
  String get apiEnvCardBaseUrlAppliedBody =>
      'ახალი მოთხოვნები ამით იმუშავებს. ჩამოტრიელი-განახლებით ან სხვა განყოფილებაში გადასვლით განაახლე უკვე ჩატისტული ეკრანები.';

  @override
  String get apiEnvCardPresets => 'სწრაფი პრესეტები';

  @override
  String get apiEnvCardPresetIos => 'iOS სიმულატორი (localhost)';

  @override
  String get apiEnvCardPresetAndroid => 'Android ემულიატორი';

  @override
  String get apiEnvCardCustomUrl =>
      'საკუთარი URL (მაგ. ლოკალურ ქსელში მოწყობილი მოწყობილობისთვის)';

  @override
  String get apiEnvCardBaseUrlField => 'საბაზისო URL';

  @override
  String get apiEnvCardBaseUrlRequired => 'შეიყვანე URL';

  @override
  String get apiEnvCardBaseUrlInvalid =>
      'URL უნდა იწყებოდეს http:// ან https://-ით';

  @override
  String get apiEnvCardApply => 'გამოყენება';

  @override
  String get apiEnvCardReset => 'ნაგულისზე დაბრუნება';

  @override
  String get tagInputDefaultHint => 'შეიყვანე და დააჭერი Enter…';

  @override
  String get userFacingErrorServerEmpty => 'სერვერმა ცარიელი პასუხი დააბრუნა.';

  @override
  String get userFacingErrorFoodPhotoRecognize =>
      'კერძელობის ფოტოზე ამოცნობა ვერ მოხერხდა. სცადე უფრო ნათელი ფოტო.';

  @override
  String get userFacingErrorFoodReanalyze =>
      'აღწერის ანალიზი ვერ მოხერხდა. სცადე სხვანაირად ჩამოტანა.';

  @override
  String get userFacingErrorBeverageRecognize =>
      'სასმელის ამოცნობა ვერ მოხერხდა. სცადე სხვა ფოტო.';

  @override
  String get userFacingErrorPhotoProcess =>
      'ფოტოს დამუშავება ვერ მოხერხდა. თავიდან სცადე.';

  @override
  String get userFacingErrorDescriptionProcess =>
      'აღწერის დამუშავება ვერ მოხერხდა. თავიდან სცადე.';

  @override
  String get userFacingErrorUploadPhoto =>
      'ფოტოს ატვირთვა ვერ მოხერხდა. შეამოწმე ფაილის ზომა (მაქს. 5 მბ).';

  @override
  String get userFacingErrorPhotoUrl => 'სერვერმა ფოტოს URL არ დააბრუნა.';

  @override
  String onboardingRequiredField(String label) {
    return 'შეავსე «$label»';
  }

  @override
  String get homeLoading => 'იტვირთება…';

  @override
  String homeGreeting(String name) {
    return 'გამარჯობა, $name!';
  }

  @override
  String get homeTrackerPreview => 'აქ იქნება კვების თრეკერი.';

  @override
  String get homeLogout => 'სისტემიდან გასვლა';

  @override
  String get photoBeverageCameraError =>
      'კამერის გახსნა ვერ მოხერხდა. სცადე გალერეიდან არჩევა.';

  @override
  String get photoBeverageGalleryError => 'გალერეის გახსნა ვერ მოხერხდა.';

  @override
  String get photoBeverageTakePhoto => 'ფოტოს გადაღება';

  @override
  String get photoBeveragePickGallery => 'არჩევა გალერეიდან';

  @override
  String trackerWaterProgress(Object current, Object goal) {
    return '$current / $goal';
  }

  @override
  String get photoFoodConfidenceHigh => 'მაღალი სიზუსტე';

  @override
  String get photoFoodConfidenceMedium => 'საშუალო სიზუსტე';

  @override
  String get photoFoodConfidenceLow => 'დაბალი სიზუსტე';

  @override
  String get photoBeverageConfidenceHigh => 'მაღალი სიზუსტე';

  @override
  String get photoBeverageConfidenceMedium => 'საშუალო სიზუსტე';

  @override
  String get photoBeverageConfidenceLow => 'დაბალი სიზუსტე';

  @override
  String get macroProteinShort => 'ც';

  @override
  String get macroCarbsShort => 'ნ';

  @override
  String get macroFatShort => 'ც';

  @override
  String get macroSugarShort => 'შ';

  @override
  String get unitGramsShort => 'გ';

  @override
  String get unitKcalShort => 'კკალ';

  @override
  String get weightHistoryLatestMissing => 'მონაცემები არ არის';

  @override
  String weightHistoryTarget(String value) {
    return 'მიზანი: $value კგ';
  }

  @override
  String weightHistoryRemaining(String value) {
    return 'დარჩა: $value კგ';
  }

  @override
  String get weightHistoryChartGoalLabel => 'მიზანი';

  @override
  String get weightHistoryMustBePositive => '0-ზე მეტი უნდა იყოს';

  @override
  String get weightHistoryTooLarge => 'ძალიან დიდი მნიშვნელობა';
}
