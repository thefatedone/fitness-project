// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'NutriMind';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonYesDelete => 'Да, удалить';

  @override
  String get commonTryAgain => 'Попробовать снова';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonError =>
      'Что-то пошло не так. Проверь соединение и попробуй снова.';

  @override
  String get commonErrorShort => 'Что-то пошло не так.';

  @override
  String get commonErrorWithRetry => 'Что-то пошло не так. Попробуй снова.';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeDescriptionLight => 'Всегда светлая тема оформления.';

  @override
  String get themeDescriptionDark => 'Всегда тёмная тема оформления.';

  @override
  String get themeDescriptionSystem =>
      'Тема оформления следует за настройкой системы.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGeorgian => 'ქართული';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageSectionLabel => 'ЯЗЫК';

  @override
  String get languageFieldTheme => 'Тема';

  @override
  String get authLoginTitle => 'NutriMind';

  @override
  String get authLoginSubtitle => 'С возвращением';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailRequired => 'Введи email';

  @override
  String get authEmailInvalid => 'Похоже, email указан неверно';

  @override
  String get authPasswordLabel => 'Пароль';

  @override
  String get authPasswordRequired => 'Введи пароль';

  @override
  String get authPasswordHelper =>
      'Мин. 8 символов, с заглавной буквы, есть цифра';

  @override
  String get authLoginButton => 'Войти';

  @override
  String get authForgotPassword => 'Забыл пароль?';

  @override
  String get authNoAccountRegister => 'Нет аккаунта? Зарегистрироваться';

  @override
  String get authServerDebugLink => 'Настройка сервера (debug)';

  @override
  String get authSessionExpired => 'Сессия истекла, войди снова.';

  @override
  String get authRegisterTitle => 'Регистрация';

  @override
  String get authRegisterName => 'Полное имя';

  @override
  String get authRegisterNameRequired => 'Введи имя';

  @override
  String get authRegisterPassword => 'Пароль';

  @override
  String get authRegisterCreate => 'Создать аккаунт';

  @override
  String get authForgotTitle => 'Восстановление пароля';

  @override
  String get authForgotInstructions =>
      'Введи email, привязанный к аккаунту — мы отправим код для сброса пароля.';

  @override
  String get authForgotSendCode => 'Отправить код';

  @override
  String get authCodeTitle => 'Введи код';

  @override
  String authCodeInstructions(String email) {
    return 'Мы отправили код на $email';
  }

  @override
  String get authCodeField => 'Код';

  @override
  String get authCodeRequired => 'Код состоит из 6 цифр';

  @override
  String get authCodeConfirm => 'Подтвердить';

  @override
  String get authCodeResend => 'Отправить код повторно';

  @override
  String get authResetTitle => 'Новый пароль';

  @override
  String authResetInstructions(String email) {
    return 'Введи новый пароль для $email';
  }

  @override
  String get authResetNewPassword => 'Новый пароль';

  @override
  String get authResetConfirmPassword => 'Подтверди пароль';

  @override
  String get authResetConfirmRequired => 'Подтверди пароль';

  @override
  String get authResetMismatch => 'Пароли не совпадают';

  @override
  String get authResetSave => 'Сохранить новый пароль';

  @override
  String get authResetSuccess => 'Пароль изменён. Теперь можешь войти.';

  @override
  String get authEmailVerifyTitle => 'Подтверждение email';

  @override
  String authEmailVerifyInstructions(String email) {
    return 'Мы отправим код подтверждения на $email';
  }

  @override
  String get authEmailVerifyEnterCode => 'Введи код из письма';

  @override
  String get authEmailVerifySendCode => 'Отправить код';

  @override
  String get authEmailVerifyResend => 'Отправить код повторно';

  @override
  String get authPasswordMinLength =>
      'Пароль должен содержать минимум 8 символов';

  @override
  String get authPasswordNeedUpper =>
      'Первая буква пароля должна быть заглавной';

  @override
  String get authPasswordNeedDigit =>
      'Пароль должен содержать хотя бы одну цифру';

  @override
  String get authServerUnreachable =>
      'Сервер не отвечает. Проверь соединение и попробуй ещё раз.';

  @override
  String get authNoConnection =>
      'Нет связи с сервером. Проверь интернет-соединение.';

  @override
  String get authSecureConnectionFailed =>
      'Не удалось установить безопасное соединение с сервером.';

  @override
  String get authRequestCancelled => 'Запрос был отменён.';

  @override
  String get authEmptyResponse => 'Сервер вернул пустой ответ.';

  @override
  String get authNoAuthToken => 'Сервер не выдал токен авторизации.';

  @override
  String get authConfirmationMissing => 'Сервер не вернул подтверждение.';

  @override
  String get onboardingStep1Title => 'Шаг 1 из 4 — Аккаунт';

  @override
  String get onboardingStep1Subtitle =>
      'Сначала соберём имя, email и пароль. Остальные шаги — позже.';

  @override
  String get onboardingStep2Title => 'Шаг 2 из 4 — Личные данные';

  @override
  String get onboardingStep2Subtitle => 'Дата рождения и пол.';

  @override
  String get onboardingStep3Title => 'Шаг 3 из 4 — Тело и цель';

  @override
  String get onboardingStep3Subtitle =>
      'Рост, вес, целевой вес, уровень активности и цель.';

  @override
  String get onboardingStep4Title => 'Шаг 4 из 4 — Питание и аллергии';

  @override
  String get onboardingStep4Subtitle =>
      'Уже почти готово! Эти поля необязательны — можешь заполнить позже в разделе Профиль.';

  @override
  String get onboardingBirthday => 'Дата рождения';

  @override
  String get onboardingBirthdayRequired => 'Укажи дату рождения';

  @override
  String get onboardingBirthdayNotSet => 'Не указана';

  @override
  String get onboardingGender => 'Пол';

  @override
  String get onboardingGenderMale => 'Мужской';

  @override
  String get onboardingGenderFemale => 'Женский';

  @override
  String get onboardingGenderOther => 'Не указывать';

  @override
  String get onboardingGenderRequired => 'Выбери вариант';

  @override
  String get onboardingDietaryPreferences =>
      'Диетические предпочтения (необязательно)';

  @override
  String get onboardingDietaryHint => 'Например, вегетарианец, кето…';

  @override
  String get onboardingAllergies =>
      'Аллергии и непереносимости (необязательно)';

  @override
  String get onboardingAllergiesHint => 'Например, орехи, молоко…';

  @override
  String get onboardingHeight => 'Рост, см';

  @override
  String get onboardingHeightHint => 'например, 175';

  @override
  String get onboardingCurrentWeight => 'Текущий вес, кг';

  @override
  String get onboardingCurrentWeightHint => 'например, 70.5';

  @override
  String get onboardingTargetWeight => 'Целевой вес, кг';

  @override
  String get onboardingTargetWeightHint => 'например, 65';

  @override
  String get onboardingActivityLevel => 'Уровень активности';

  @override
  String get onboardingActivityLevelRequired => 'Выбери уровень активности';

  @override
  String get onboardingPrimaryGoal => 'Главная цель';

  @override
  String get onboardingPrimaryGoalRequired => 'Выбери главную цель';

  @override
  String onboardingPaceLabel(String value) {
    return 'Темп: $value кг/неделю';
  }

  @override
  String onboardingPaceChipLabel(String value) {
    return '$value кг/нед.';
  }

  @override
  String get onboardingRequired => 'Заполни';

  @override
  String get onboardingEnterNumber => 'Введи число';

  @override
  String get onboardingMustBePositive => 'Должно быть > 0';

  @override
  String get onboardingBack => 'Назад';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingFinish => 'Завершить регистрацию';

  @override
  String get onboardingGenericError => 'Не удалось зарегистрироваться.';

  @override
  String get onboardingPartialSaveWarning =>
      'Профиль создан, но некоторые данные не сохранились — заполни их позже в разделе Профиль.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSectionAppearance => 'ВНЕШНИЙ ВИД';

  @override
  String get settingsSectionTheme => 'Тема оформления';

  @override
  String get settingsSectionAccount => 'АККАУНТ';

  @override
  String get settingsSectionAbout => 'О ПРИЛОЖЕНИИ';

  @override
  String get settingsSectionApiEnvironmentDebug =>
      'API-ОКРУЖЕНИЕ (ТОЛЬКО ДЛЯ РАЗРАБОТКИ)';

  @override
  String get settingsChangePassword => 'Сменить пароль';

  @override
  String get settingsDeleteAccount => 'Удалить аккаунт';

  @override
  String get settingsVersion => 'Версия';

  @override
  String get settingsLogout => 'Выйти из аккаунта';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileSave => 'Сохранить изменения';

  @override
  String get profileUpdated => 'Профиль обновлён';

  @override
  String get profileUpdateError => 'Не удалось сохранить.';

  @override
  String get profileSavePhotoTitle => 'Откуда взять фото?';

  @override
  String get profilePhotoCamera => 'Сделать фото';

  @override
  String get profilePhotoGallery => 'Выбрать из галереи';

  @override
  String get profilePhotoCropTitle => 'Обрезать фото';

  @override
  String get profilePhotoCropError =>
      'Не удалось обрезать фото. Попробуй ещё раз.';

  @override
  String get profilePhotoReadError => 'Не удалось прочитать обрезанное фото.';

  @override
  String get profilePhotoTooLarge => 'Фото слишком большое, попробуй другое';

  @override
  String get profilePhotoUpdated => 'Фото обновлено';

  @override
  String get profileCameraError =>
      'Не удалось открыть камеру. Попробуй выбрать фото из галереи.';

  @override
  String get profileGalleryError => 'Не удалось открыть галерею.';

  @override
  String get profileSectionBasic => 'Основное';

  @override
  String get profileSectionBody => 'Параметры тела';

  @override
  String get profileSectionGoalActivity => 'Цель и активность';

  @override
  String get profileFieldName => 'Имя';

  @override
  String get profileFieldBirthday => 'Дата рождения';

  @override
  String get profileFieldGender => 'Пол';

  @override
  String get profileMetricHeight => 'Рост, см';

  @override
  String get profileMetricHeightHint => 'например, 175';

  @override
  String get profileMetricCurrentWeight => 'Текущий вес, кг';

  @override
  String get profileMetricCurrentWeightHint => 'например, 70.5';

  @override
  String get profileMetricTargetWeight => 'Целевой вес, кг';

  @override
  String get profileMetricTargetWeightHint => 'например, 65';

  @override
  String profileBmiLabel(String label) {
    return 'ИМТ: $label';
  }

  @override
  String get profileViewWeightHistory => 'Посмотреть историю веса';

  @override
  String get profilePrimaryGoal => 'Главная цель';

  @override
  String get profileActivityLevel => 'Уровень активности';

  @override
  String profilePace(String value) {
    return 'Темп похудения: $value кг/неделю';
  }

  @override
  String profilePaceChip(String value) {
    return '$value кг/нед.';
  }

  @override
  String get profileDietaryPreferences => 'Диетические предпочтения';

  @override
  String get profileDietaryHint => 'Например, вегетарианец…';

  @override
  String get profileAllergies => 'Аллергии и непереносимости';

  @override
  String get profileAllergiesAiHint =>
      'Используется AI-распознаванием фото для предупреждений о конфликтах.';

  @override
  String get profileAllergiesHint => 'Например, орехи…';

  @override
  String get profileBmiUnderweight => 'Недостаточный вес';

  @override
  String get profileBmiNormal => 'Норма';

  @override
  String get profileBmiOverweight => 'Избыточный вес';

  @override
  String get profileBmiObese => 'Ожирение';

  @override
  String get dietVegetarian => 'Вегетарианец';

  @override
  String get dietVegan => 'Веган';

  @override
  String get dietKeto => 'Кето';

  @override
  String get dietPaleo => 'Палео';

  @override
  String get dietLowCarb => 'Низкоуглеводная';

  @override
  String get dietLowFat => 'Низкожировая';

  @override
  String get dietMediterranean => 'Средиземноморская';

  @override
  String get dietHalal => 'Халяль';

  @override
  String get dietKosher => 'Кошер';

  @override
  String get allergyNuts => 'Орехи';

  @override
  String get allergyShellfish => 'Морепродукты';

  @override
  String get allergyEggs => 'Яйца';

  @override
  String get allergySoy => 'Соя';

  @override
  String get allergyWheat => 'Пшеница';

  @override
  String get allergyFish => 'Рыба';

  @override
  String get allergyMilk => 'Молоко';

  @override
  String get activitySedentary => 'Малоподвижный';

  @override
  String get activityLightlyActive => 'Лёгкая активность';

  @override
  String get activityModeratelyActive => 'Умеренная активность';

  @override
  String get activityVeryActive => 'Высокая активность';

  @override
  String get activityExtraActive => 'Очень высокая активность';

  @override
  String get goalLoseWeight => 'Похудение';

  @override
  String get goalMaintain => 'Поддержание веса';

  @override
  String get goalGainMuscle => 'Набор массы';

  @override
  String get goalEatHealthier => 'Здоровое питание';

  @override
  String get deleteAccountTitle => 'Удаление аккаунта';

  @override
  String get deleteAccountWarningTitle => 'Это действие необратимо';

  @override
  String get deleteAccountWarningBody =>
      'Будут безвозвратно удалены: твой профиль, вся история питания, вес, фотографии и переписка с AI-ассистентом. Это действие нельзя отменить.';

  @override
  String get deleteAccountAcknowledge =>
      'Я понимаю, что это действие нельзя отменить';

  @override
  String get deleteAccountAcknowledgeRequired =>
      'Подтверди, что понимаешь риск';

  @override
  String get deleteAccountCurrentPassword => 'Текущий пароль';

  @override
  String get deleteAccountCurrentPasswordRequired => 'Введи текущий пароль';

  @override
  String get deleteAccountHelperBeforeAck =>
      'Сначала подтверди, что понимаешь риск';

  @override
  String get deleteAccountHelperAfterAck =>
      'Подтверди пароль, чтобы продолжить';

  @override
  String get deleteAccountConfirmButton => 'Удалить аккаунт навсегда';

  @override
  String get deleteAccountDialogTitle => 'Точно удалить аккаунт?';

  @override
  String get deleteAccountDialogBody =>
      'Это последнее предупреждение. Все твои данные будут удалены без возможности восстановления.';

  @override
  String get deleteAccountWrongPasswordMatch => 'Текущий пароль неверен';

  @override
  String get changePasswordTitle => 'Смена пароля';

  @override
  String get changePasswordCurrent => 'Текущий пароль';

  @override
  String get changePasswordCurrentRequired => 'Введи текущий пароль';

  @override
  String get changePasswordNew => 'Новый пароль';

  @override
  String get changePasswordConfirm => 'Подтверди новый пароль';

  @override
  String get changePasswordConfirmRequired => 'Подтверди пароль';

  @override
  String get changePasswordSave => 'Изменить пароль';

  @override
  String get trackerTitle => 'Трекер';

  @override
  String get trackerDateToday => 'Сегодня';

  @override
  String get trackerDateYesterday => 'Вчера';

  @override
  String get trackerDeleteRecordTitle => 'Удалить запись?';

  @override
  String trackerDeleteRecordBody(String name) {
    return '«$name» будет удалена из сегодняшнего дневника.';
  }

  @override
  String get trackerMealPickerTitle => 'К какому приёму пищи отнести?';

  @override
  String get trackerCameraChoiceTitle => 'Что фотографируем?';

  @override
  String get trackerCameraFood => 'Сфотографировать еду';

  @override
  String get trackerCameraFoodSubtitle =>
      'Узнать КБЖУ и добавить запись в дневник';

  @override
  String get trackerCameraBeverage => 'Сфотографировать напиток';

  @override
  String get trackerCameraBeverageSubtitle =>
      'Авто-добавление воды и калорий в один шаг';

  @override
  String get trackerEmptyLog => 'Пока нет записей';

  @override
  String trackerFoodSubtitle(
    String calories,
    String protein,
    String carbs,
    String fat,
  ) {
    return '$calories ккал • Б/У/Ж $protein/$carbs/$fat г';
  }

  @override
  String get trackerCaloriesToday => 'Калории сегодня';

  @override
  String get trackerCaloriesEaten => 'Калорий съедено';

  @override
  String trackerCaloriesKcalOf(String target) {
    return ' / $target ккал';
  }

  @override
  String get trackerCaloriesKcalOnly => ' ккал';

  @override
  String get trackerWaterTitle => 'Вода';

  @override
  String get trackerWaterGoalReached => 'Цель достигнута!';

  @override
  String trackerWaterPctOfGoal(String pct) {
    return '$pct% дневной цели';
  }

  @override
  String trackerWaterRemaining(String amount) {
    return '$amount осталось';
  }

  @override
  String get trackerWaterError => 'Не удалось сохранить.';

  @override
  String get trackerWaterAddTitle => 'Добавить воду';

  @override
  String get trackerWaterAddInstructions =>
      'Введи количество в литрах (0.1–10 л)';

  @override
  String get trackerWaterLiters => 'Литры';

  @override
  String get trackerWaterHint => 'например, 0.5';

  @override
  String get trackerWaterRequired => 'Введи количество';

  @override
  String get trackerWaterMin => 'Минимум 0.1 л';

  @override
  String get trackerWaterMax => 'Максимум 10 л';

  @override
  String get trackerWeightCardTitle => 'Вес';

  @override
  String trackerWeightCardCurrent(String value) {
    return 'Текущий вес: $value кг';
  }

  @override
  String get trackerWeightCardAdd => 'Добавить вес';

  @override
  String get trackerDockCameraTooltip => 'Камера';

  @override
  String get trackerDockChatTooltip => 'Чат с NutriBot';

  @override
  String get trackerDockAddFoodTooltip => 'Добавить еду';

  @override
  String get trackerDockProfileTooltip => 'Профиль';

  @override
  String get trackerDockSettingsTooltip => 'Настройки';

  @override
  String get trackerDatePrevTooltip => 'Предыдущий день';

  @override
  String get trackerDateNextTooltip => 'Следующий день';

  @override
  String get trackerTooltipDelete => 'Удалить';

  @override
  String get trackerTooltipRefine => 'Уточнить';

  @override
  String get trackerMealBreakfast => 'Завтрак';

  @override
  String get trackerMealLunch => 'Обед';

  @override
  String get trackerMealDinner => 'Ужин';

  @override
  String get trackerMealSnack => 'Перекус';

  @override
  String get trackerMealDrinks => 'Напитки';

  @override
  String get addFoodTitle => 'Добавить еду';

  @override
  String get addFoodMealLabel => 'Приём пищи';

  @override
  String get addFoodMealBreakfast => 'Завтрак';

  @override
  String get addFoodMealLunch => 'Обед';

  @override
  String get addFoodMealDinner => 'Ужин';

  @override
  String get addFoodMealSnack => 'Перекус';

  @override
  String get addFoodName => 'Название';

  @override
  String get addFoodQuantity => 'Количество';

  @override
  String get addFoodUnit => 'Ед.';

  @override
  String get addFoodUnitG => 'г';

  @override
  String get addFoodUnitMl => 'мл';

  @override
  String get addFoodUnitPcs => 'шт';

  @override
  String get addFoodCalories => 'Калории, ккал';

  @override
  String get addFoodProtein => 'Белки, г';

  @override
  String get addFoodCarbs => 'Углеводы, г';

  @override
  String get addFoodFat => 'Жиры, г';

  @override
  String get addFoodFiber => 'Клетчатка, г (необязательно)';

  @override
  String get addFoodButtonAdd => 'Добавить';

  @override
  String addFoodFieldRequired(String label) {
    return 'Заполни «$label»';
  }

  @override
  String get addFoodEnterNumber => 'Введи число';

  @override
  String get addFoodMustBeNonNegative => 'Должно быть ≥ 0';

  @override
  String get addFoodMustBePositive => 'Должно быть > 0';

  @override
  String get photoFoodTitle => 'Фото еды';

  @override
  String get photoFoodCameraError =>
      'Не удалось открыть камеру. Попробуй выбрать фото из галереи.';

  @override
  String get photoFoodGalleryError => 'Не удалось открыть галерею.';

  @override
  String get photoFoodInstructions =>
      'Сфотографируй еду или выбери снимок из галереи';

  @override
  String get photoFoodTakePhoto => 'Сделать фото';

  @override
  String get photoFoodPickGallery => 'Выбрать из галереи';

  @override
  String get photoFoodAnalyzing => 'Анализируем фото…';

  @override
  String get photoFoodErrorTitle =>
      'Не удалось распознать блюдо на фото. Попробуй сделать более чёткое фото.';

  @override
  String get photoFoodAllergyWarningTitle => '⚠️ Возможен конфликт с аллергией';

  @override
  String photoFoodAllergyWarningBullet(String text) {
    return '•  $text';
  }

  @override
  String get photoFoodNoName => 'Без названия';

  @override
  String get photoFoodIngredientsTitle => 'Что распознано';

  @override
  String get photoBeverageTitle => 'Фото напитка';

  @override
  String get photoBeverageInstructions =>
      'Сфотографируй напиток или выбери снимок из галереи';

  @override
  String get photoBeverageAnalyzing => 'Анализируем фото…';

  @override
  String get photoBeverageSugar => 'Сахар';

  @override
  String photoBeverageMl(String value) {
    return '$value мл';
  }

  @override
  String get photoBeverageUnsure =>
      'Не уверен(а) в определении — проверь и подтверди данные.';

  @override
  String get photoBeverageDescriptionMissing => '— описание отсутствует';

  @override
  String get photoBeverageNameLabel => 'Название напитка';

  @override
  String get photoBeverageNameRequired => 'Введи название';

  @override
  String get photoBeverageVolumeLabel => 'Объём, мл';

  @override
  String get photoBeverageVolumeRequired => 'Введи объём';

  @override
  String get photoBeverageCaloriesLabel => 'Калории, ккал';

  @override
  String get photoBeverageMoreDetails =>
      'Подробнее (белки, жиры, углеводы, сахар)';

  @override
  String get photoBeverageProteinLabel => 'Белки, г';

  @override
  String get photoBeverageCarbsLabel => 'Углеводы, г';

  @override
  String get photoBeverageFatLabel => 'Жиры, г';

  @override
  String get photoBeverageSugarLabel => 'Сахар, г';

  @override
  String get photoBeverageNonNegative => 'Не может быть отрицательным';

  @override
  String get photoBeveragePositiveRequired => 'Объём должен быть больше 0';

  @override
  String get photoBeverageConfirm => 'Подтвердить и сохранить';

  @override
  String get photoBeverageSaved => 'Напиток сохранён';

  @override
  String get photoBeverageSaveError =>
      'Не удалось сохранить напиток. Попробуй снова.';

  @override
  String photoBeverageMismatchWarning(String name) {
    return 'Судя по фото, это не похоже на «$name».';
  }

  @override
  String photoBeverageMismatchLooksLike(String suggestion) {
    return 'Больше похоже на: $suggestion.';
  }

  @override
  String get photoBeverageMismatchFix => 'Исправить';

  @override
  String get photoBeverageMismatchProceed => 'Всё равно сохранить';

  @override
  String get photoBeverageVerifyFailed =>
      'Не удалось проверить соответствие фото — сохранено без проверки.';

  @override
  String get editFoodTitle => 'Уточнить описание';

  @override
  String get editFoodHint =>
      'Например: это бурый рис, а не белый, и масла было меньше';

  @override
  String get editFoodRequired =>
      'Введи описание — его отправим в ИИ для пересчёта.';

  @override
  String get editFoodHelpText =>
      'Опиши, что на самом деле в блюде — это поможет точнее пересчитать калории и макросы. Изображение не используется.';

  @override
  String get editFoodRecalculate => 'Пересчитать';

  @override
  String get editFoodAnalyzing => 'Анализируем описание…';

  @override
  String get editFoodConfidenceHigh => 'Высокая точность';

  @override
  String get editFoodConfidenceMedium => 'Средняя точность';

  @override
  String get editFoodConfidenceLow => 'Низкая точность';

  @override
  String get editFoodNoDescription => '— описание отсутствует';

  @override
  String get editFoodRecalcBadge => 'Пересчитано';

  @override
  String get trackerFoodProtein => 'Белки';

  @override
  String get trackerFoodCarbs => 'Углеводы';

  @override
  String get trackerFoodFat => 'Жиры';

  @override
  String get weightHistoryTitle => 'История веса';

  @override
  String get weightHistoryAddTitle => 'Добавить запись о весе';

  @override
  String get weightHistoryWeight => 'Вес, кг';

  @override
  String get weightHistoryWeightHint => 'например, 70.5';

  @override
  String get weightHistoryWeightRequired => 'Введи вес';

  @override
  String get weightHistoryWeightMustBePositive => 'Вес должен быть больше 0';

  @override
  String get weightHistoryNote => 'Заметка (необязательно)';

  @override
  String get weightHistoryNoteHint => 'например, утренний замер';

  @override
  String get weightHistorySave => 'Сохранить';

  @override
  String get weightHistoryErrorSave => 'Не удалось сохранить.';

  @override
  String get weightHistoryDeleteTitle => 'Удалить запись?';

  @override
  String get weightHistoryDeleteBody =>
      'Эта запись о весе будет удалена без возможности восстановления.';

  @override
  String get weightHistoryEmpty => 'Пока нет записей';

  @override
  String get chatTitle => 'Чат';

  @override
  String get chatClearHistoryTitle => 'Удалить всю историю переписки?';

  @override
  String get chatClearHistoryBody => 'Это действие необратимо.';

  @override
  String get chatClearHistoryConfirm => 'Удалить';

  @override
  String get chatMenuTooltip => 'Меню';

  @override
  String get chatMenuClearHistory => 'Очистить историю';

  @override
  String get chatEmptyState =>
      'Спроси меня о питании, целях по калориям или продуктах!';

  @override
  String get chatInputHint => 'Спроси о питании...';

  @override
  String get chatSendTooltip => 'Отправить';

  @override
  String get chatError => 'Что-то пошло не так. Попробуй ещё раз.';

  @override
  String get emailVerifyBannerMessage =>
      'Подтверди свой email, чтобы не потерять доступ к аккаунту.';

  @override
  String get emailVerifyBannerAction => 'Подтвердить';

  @override
  String get emailVerifyBannerDismissTooltip => 'Скрыть';

  @override
  String get apiEnvCardTitle => 'API-окружение (только для разработки)';

  @override
  String get apiEnvCardCurrentUrl => 'Текущий URL';

  @override
  String apiEnvCardBaseUrlApplied(String url) {
    return 'Базовый URL: $url';
  }

  @override
  String get apiEnvCardBaseUrlAppliedBody =>
      'Новые запросы уже пойдут по нему. Потяни экран или перейди в другой раздел, чтобы обновить уже загруженные экраны.';

  @override
  String get apiEnvCardPresets => 'Быстрые пресеты';

  @override
  String get apiEnvCardPresetIos => 'iOS Simulator (localhost)';

  @override
  String get apiEnvCardPresetAndroid => 'Android Emulator';

  @override
  String get apiEnvCardCustomUrl =>
      'Свой URL (например, для устройства в локальной сети)';

  @override
  String get apiEnvCardBaseUrlField => 'Базовый URL';

  @override
  String get apiEnvCardBaseUrlRequired => 'Введи URL';

  @override
  String get apiEnvCardBaseUrlInvalid =>
      'URL должен начинаться с http:// или https://';

  @override
  String get apiEnvCardApply => 'Применить';

  @override
  String get apiEnvCardReset => 'Сбросить к умолчанию';

  @override
  String get tagInputDefaultHint => 'Введи и нажми Enter…';

  @override
  String get userFacingErrorServerEmpty => 'Сервер вернул пустой ответ.';

  @override
  String get userFacingErrorFoodPhotoRecognize =>
      'Не удалось распознать блюдо на фото. Попробуй сделать более чёткое фото.';

  @override
  String get userFacingErrorFoodReanalyze =>
      'Не удалось проанализировать описание. Попробуй переформулировать.';

  @override
  String get userFacingErrorBeverageRecognize =>
      'Не удалось распознать напиток. Попробуй другое фото.';

  @override
  String get userFacingErrorPhotoProcess =>
      'Не удалось обработать фото. Попробуй снова.';

  @override
  String get userFacingErrorDescriptionProcess =>
      'Не удалось обработать описание. Попробуй снова.';

  @override
  String get userFacingErrorUploadPhoto =>
      'Не удалось загрузить фото. Проверь размер файла (макс. 5 МБ).';

  @override
  String get userFacingErrorPhotoUrl => 'Сервер не вернул ссылку на фото.';

  @override
  String onboardingRequiredField(String label) {
    return 'Заполни «$label»';
  }

  @override
  String get homeLoading => 'Загрузка...';

  @override
  String homeGreeting(String name) {
    return 'Привет, $name!';
  }

  @override
  String get homeTrackerPreview => 'Здесь будет трекер питания.';

  @override
  String get homeLogout => 'Выйти';

  @override
  String get photoBeverageCameraError =>
      'Не удалось открыть камеру. Попробуй выбрать фото из галереи.';

  @override
  String get photoBeverageGalleryError => 'Не удалось открыть галерею.';

  @override
  String get photoBeverageTakePhoto => 'Сделать фото';

  @override
  String get photoBeveragePickGallery => 'Выбрать из галереи';

  @override
  String trackerWaterProgress(Object current, Object goal) {
    return '$current / $goal';
  }

  @override
  String get photoFoodConfidenceHigh => 'Высокая точность';

  @override
  String get photoFoodConfidenceMedium => 'Средняя точность';

  @override
  String get photoFoodConfidenceLow => 'Низкая точность';

  @override
  String get photoBeverageConfidenceHigh => 'Высокая точность';

  @override
  String get photoBeverageConfidenceMedium => 'Средняя точность';

  @override
  String get photoBeverageConfidenceLow => 'Низкая точность';

  @override
  String get macroProteinShort => 'Б';

  @override
  String get macroCarbsShort => 'У';

  @override
  String get macroFatShort => 'Ж';

  @override
  String get macroSugarShort => 'Сахар';

  @override
  String get unitGramsShort => 'г';

  @override
  String get unitKcalShort => 'ккал';

  @override
  String get weightHistoryLatestMissing => 'Нет данных';

  @override
  String weightHistoryTarget(String value) {
    return 'Цель: $value кг';
  }

  @override
  String weightHistoryRemaining(String value) {
    return 'Осталось: $value кг';
  }

  @override
  String get weightHistoryChartGoalLabel => 'Цель';

  @override
  String get weightHistoryMustBePositive => 'Должен быть > 0';

  @override
  String get weightHistoryTooLarge => 'Слишком большое значение';
}
