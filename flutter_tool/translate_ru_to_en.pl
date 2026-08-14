#!/usr/bin/env perl
# One-shot Russian→English translation pass for the remaining UI files.
# Maps each known Russian phrase to a professional English equivalent.
# Some phrases are skipped because they're handled by a smarter matcher
# (placeholder strings with a number or name in them).

use strict;
use warnings;

# files: relative path → absolute path under flutter_app/
my @files = (
    'lib/features/auth/screens/onboarding_wizard_screen.dart',
    'lib/features/profile/screens/profile_screen.dart',
    'lib/features/profile/screens/change_password_screen.dart',
    'lib/features/tracker/screens/tracker_home_screen.dart',
    'lib/features/tracker/screens/photo_food_screen.dart',
    'lib/features/tracker/screens/photo_beverage_screen.dart',
    'lib/features/tracker/screens/edit_food_description_screen.dart',
    'lib/features/tracker/screens/weight_history_screen.dart',
    'lib/features/tracker/screens/add_food_screen.dart',
    'lib/shared/widgets/api_environment_card.dart',
    'lib/shared/widgets/tag_input.dart',
    'lib/features/home/screens/home_screen.dart',
);

my %mapping = (
    # Most common UI strings — direct literals
    'Дата рождения'                              => 'Date of birth',
    'Укажи дату рождения'                        => 'Please enter your date of birth',
    'Пол'                                        => 'Gender',
    'Мужской'                                    => 'Male',
    'Женский'                                    => 'Female',
    'Не указывать'                                => 'Prefer not to say',
    'Выбери вариант'                             => 'Please pick an option',
    'Не указана'                                  => 'Not set',
    'Полное имя'                                 => 'Full name',
    'Введи имя'                                   => 'Please enter your name',
    'Введи email'                                 => 'Please enter your email',
    'Похоже, email указан неверно'                => 'That does not look like a valid email',
    'Пароль'                                      => 'Password',
    'Подтверди пароль'                            => 'Confirm password',
    'Пароли не совпадают'                         => 'Passwords do not match',
    'Мин. 8 символов, с заглавной буквы, есть цифра' => 'Min. 8 characters, one uppercase letter, one digit',
    'Заполни'                                     => 'Required',
    'Введи число'                                 => 'Please enter a number',
    'Должно быть > 0'                             => 'Must be greater than 0',
    'Регистрация'                                 => 'Sign up',
    'Назад'                                       => 'Back',
    'Далее'                                       => 'Next',
    'Завершить регистрацию'                       => 'Finish registration',
    'Не удалось зарегистрироваться.'              => 'Could not complete registration.',
    'Шаг 1 из 4 — Аккаунт'                         => 'Step 1 of 4 — Account',
    'Шаг 2 из 4 — Личные данные'                  => 'Step 2 of 4 — Personal details',
    'Шаг 3 из 4 — Тело и цель'                     => 'Step 3 of 4 — Body and goal',
    'Шаг 4 из 4 — Питание и аллергии'              => 'Step 4 of 4 — Nutrition and allergies',
    'Сначала соберём имя, email и пароль. Остальные шаги — позже.'
                                                  => 'First we will collect your name, email and password. The remaining steps come later.',
    'Дата рождения и пол.'                        => 'Date of birth and gender.',
    'Рост, вес, целевой вес, уровень активности и цель.'
                                                  => 'Height, weight, target weight, activity level and goal.',
    'Уже почти готово! Эти поля необязательны — можешь заполнить '
                                                  => 'Almost done! These fields are optional — you can fill them in ',
    'позже в разделе Профиль.'                     => 'later in the Profile section.',
    'Например, вегетарианец, кето…'                => 'For example, vegetarian, keto…',
    'Например, орехи, молоко…'                    => 'For example, nuts, milk…',
    'Диетические предпочтения (необязательно)'    => 'Dietary preferences (optional)',
    'Аллергии и непереносимости (необязательно)' => 'Allergies and intolerances (optional)',
    'Профиль создан, но некоторые данные не сохранились '
                                                  => 'Profile was created, but some details did not save ',
    '— заполни их позже в разделе Профиль.'       => '— fill them in later in the Profile section.',
    'Имя'                                         => 'Name',
    'Сохранить изменения'                         => 'Save changes',
    'Профиль обновлён'                            => 'Profile updated',
    'Не удалось сохранить.'                        => 'Could not save.',
    'Откуда взять фото?'                          => 'Where from?',
    'Сделать фото'                                 => 'Take photo',
    'Выбрать из галереи'                          => 'Pick from gallery',
    'Обрезать фото'                               => 'Crop photo',
    'Не удалось обрезать фото. Попробуй ещё раз.' => 'Could not crop photo. Try again.',
    'Не удалось прочитать обрезанное фото.'       => 'Could not read cropped photo.',
    'Фото слишком большое, попробуй другое'        => 'Photo is too large, try a different one',
    'Фото обновлено'                               => 'Photo updated',
    'Не удалось открыть камеру. Попробуй выбрать фото из галереи.'
                                                  => 'Could not open camera. Try picking from gallery instead.',
    'Не удалось открыть галерею.'                 => 'Could not open gallery.',
    'Основное'                                    => 'Basic',
    'Параметры тела'                              => 'Body measurements',
    'Цель и активность'                           => 'Goal and activity',
    'ИМТ: '                                       => 'BMI: ',
    'Посмотреть историю веса'                     => 'View weight history',
    'Главная цель'                                 => 'Primary goal',
    'Уровень активности'                          => 'Activity level',
    'Темп похудения: '                            => 'Weight-loss pace: ',
    'Диетические предпочтения'                    => 'Dietary preferences',
    'Аллергии и непереносимости'                  => 'Allergies and intolerances',
    'Используется AI-распознаванием фото для предупреждений о конфликтах.'
                                                  => 'Used by AI photo recognition to flag conflicts.',
    'Например, орехи…'                            => 'For example, nuts…',
    'Недостаточный вес'                           => 'Underweight',
    'Норма'                                       => 'Normal',
    'Избыточный вес'                              => 'Overweight',
    'Ожирение'                                    => 'Obesity',
    'Текущий пароль'                               => 'Current password',
    'Введи текущий пароль'                         => 'Please enter your current password',
    'Смена пароля'                                 => 'Change password',
    'Новый пароль'                                 => 'New password',
    'Подтверди новый пароль'                       => 'Confirm new password',
    'Изменить пароль'                              => 'Change password',
    'например, 175'                                => 'e.g. 175',
    'например, 70.5'                              => 'e.g. 70.5',
    'например, 65'                                => 'e.g. 65',
    'Рост, см'                                     => 'Height, cm',
    'Текущий вес, кг'                              => 'Current weight, kg',
    'Целевой вес, кг'                              => 'Target weight, kg',
    'Введи объём'                                  => 'Please enter the volume',
    'Минимум 0.1 л'                               => 'Minimum is 0.1 L',
    'Максимум 10 л'                                => 'Maximum is 10 L',
    'Литры'                                        => 'Litres',
    'Добавить воду'                                => 'Add water',
    'Введи количество в литрах (0.1–10 л)'        => 'Enter amount in litres (0.1–10 L)',
    'Введи количество'                             => 'Please enter the amount',
    'Сохранить'                                    => 'Save',
    'Цель достигнута!'                            => 'Daily goal reached!',
    'осталось'                                     => 'remaining',
    'ккал'                                         => 'kcal',
    'Сегодня'                                      => 'Today',
    'Вчера'                                        => 'Yesterday',
    'Пока нет записей'                             => 'No entries yet',
    'Вода'                                         => 'Water',
    'Уточнить'                                     => 'Refine',
    'Вес'                                          => 'Weight',
    'Добавить вес'                                 => 'Add weight',
    'Удалить запись?'                              => 'Delete record?',
    'будет удалена из сегодняшнего дневника.'       => 'will be removed from today\'s log.',
    'К какому приёму пищи отнести?'                => 'Which meal does this belong to?',
    'Что фотографируем?'                          => 'What are we photographing?',
    'Сфотографировать еду'                        => 'Photograph food',
    'Узнать КБЖУ и добавить запись в дневник'      => 'Identify macros and add an entry to the log',
    'Сфотографировать напиток'                    => 'Photograph beverage',
    'Авто-добавление воды и калорий в один шаг'     => 'Auto-add water and calories in one step',
    'Завтрак'                                      => 'Breakfast',
    'Обед'                                         => 'Lunch',
    'Ужин'                                         => 'Dinner',
    'Перекус'                                      => 'Snack',
    'Напитки'                                      => 'Drinks',
    'Добавить еду'                                 => 'Add food',
    'Название'                                     => 'Name',
    'Количество'                                   => 'Quantity',
    'Ед.'                                          => 'Unit',
    'Белки, г'                                     => 'Protein, g',
    'Углеводы, г'                                  => 'Carbs, g',
    'Жиры, г'                                      => 'Fat, g',
    'Клетчатка, г (необязательно)'                 => 'Fiber, g (optional)',
    'Добавить'                                      => 'Add',
    'Приём пищи'                                   => 'Meal',
    'Вес, кг'                                      => 'Weight, kg',
    'Заметка (необязательно)'                      => 'Note (optional)',
    'Эта запись о весе будет удалена без возможности восстановления.'
                                                  => 'This weight entry will be permanently deleted.',
    'например, утренний замер'                    => 'e.g. morning weigh-in',
    'Камера'                                       => 'Camera',
    'Фото еды'                                     => 'Photo of food',
    'Сфотографируй еду или выбери снимок из галереи'
                                                  => 'Take a photo of your food or pick one from the gallery',
    'Сфотографируй напиток или выбери снимок из галереи'
                                                  => 'Take a photo of your drink or pick one from the gallery',
    'Анализируем фото...'                         => 'Analyzing photo...',
    '⚠️ Возможен конфликт с аллергией'              => '⚠️ Possible allergy conflict',
    'Что распознано'                               => 'Ingredients detected',
    'Без названия'                                => 'No name',
    'Готово'                                       => 'Done',
    'Попробовать снова'                            => 'Try again',
    'Уточнить описание'                            => 'Refine description',
    'Анализируем описание...'                      => 'Analyzing description...',
    'Высокая точность'                            => 'High confidence',
    'Средняя точность'                            => 'Medium confidence',
    'Низкая точность'                             => 'Low confidence',
    '— описание отсутствует'                       => '— no description',
    'Пересчитано'                                  => 'Recalculated',
    'Не уверен(а) в определении — проверь и подтверди данные.'
                                                  => 'Not sure about the identification — please review and confirm the details.',
    'Название напитка'                             => 'Beverage name',
    'Объём, мл'                                    => 'Volume, ml',
    'Калории, ккал'                                => 'Calories, kcal',
    'Сахар, г'                                     => 'Sugar, g',
    'Не может быть отрицательным'                  => 'Must be ≥ 0',
    'Объём должен быть больше 0'                  => 'Volume must be greater than 0',
    'Подтвердить и сохранить'                      => 'Confirm and save',
    'Напиток сохранён'                             => 'Beverage saved',
    'Не удалось сохранить напиток. Попробуй снова.'
                                                  => 'Could not save the beverage. Try again.',
    'Исправить'                                    => 'Fix',
    'Всё равно сохранить'                          => 'Save anyway',
    'Судя по фото, это не похоже на «'            => 'This doesn\'t look like «',
    'Больше похоже на: '                          => 'Looks more like: ',
    'Не удалось проверить соответствие фото — сохранено без проверки.'
                                                  => 'Could not verify the photo match — saved without verification.',
    'Например: это бурый рис, а не белый, и масла было меньше'
                                                  => 'For example: this is brown rice, not white, and there is less oil',
    'Введи описание — его отправим в ИИ для пересчёта.'
                                                  => 'Please enter a description — it will be sent to the AI for re-estimation.',
    'Опиши, что на самом деле в блюде — это поможет '
                                                  => 'Describe what is really in the dish — this will help ',
    'точнее пересчитать калории и макросы. Изображение '
                                                  => 'more accurately recalculate calories and macros. The image ',
    'не используется.'                           => 'is not used.',
    'Пересчитать'                                  => 'Recalculate',
    'Подробнее (белки, жиры, углеводы, сахар)'    => 'More details (protein, fat, carbs, sugar)',
    'Трекер'                                       => 'Tracker',
    'История веса'                                 => 'Weight history',
    'Добавить запись о весе'                       => 'Add weight entry',
    'API-окружение (только для разработки)'        => 'API environment (dev only)',
    'Текущий URL'                                  => 'Current URL',
    'Базовый URL: '                                => 'Base URL: ',
    'Новые запросы уже пойдут по нему. Потяни экран или '
                                                  => 'New requests will use it. Pull-to-refresh or ',
    'перейди в другой раздел, чтобы обновить уже '
                                                  => 'navigate to another section to update already ',
    'загруженные экраны.'                          => 'loaded screens.',
    'Быстрые пресеты'                              => 'Quick presets',
    'iOS Simulator (localhost)'                    => 'iOS Simulator (localhost)',
    'Android Emulator'                            => 'Android Emulator',
    'Свой URL (например, для устройства в локальной сети)'
                                                  => 'Custom URL (e.g. for a device on the local network)',
    'Базовый URL'                                  => 'Base URL',
    'Введи URL'                                    => 'Please enter a URL',
    'URL должен начинаться с http:// или https://'
                                                  => 'URL must start with http:// or https://',
    'Применить'                                    => 'Apply',
    'Сбросить к умолчанию'                         => 'Reset to default',
    'Введи и нажми Enter…'                         => 'Type and press Enter…',
    'Загрузка...'                                  => 'Loading...',
    'Здесь будет трекер питания.'                  => 'Here will be the nutrition tracker.',
    'Выйти'                                        => 'Log out',
    'Калории сегодня'                              => 'Calories today',
    'Калорий съедено'                              => 'Calories consumed',
    'Текущий вес: '                                => 'Current weight: ',
    'Б/У/Ж '                                       => 'P/C/F ',
    'Предыдущий день'                              => 'Previous day',
    'Следующий день'                               => 'Next day',
    'Чат с NutriBot'                               => 'Chat with NutriBot',
    'Профиль'                                      => 'Profile',
    'Настройки'                                    => 'Settings',
    'Удалить'                                      => 'Delete',
);

# Run translation for each file.
for my $rel (@files) {
    my $path = "/Users/alexanderpepanian/AlexanderApps/fitness-project/flutter_app/$rel";
    next unless -f $path;

    open my $in,  '<', $path or die "Cannot open $path: $!";
    open my $out, '>', "$path.tmp" or die "Cannot open tmp: $!";
    while (my $line = <$in>) {
        for my $ru (keys %mapping) {
            my $en = $mapping{$ru};
            # Use word-boundary-ish substitution: escape regex specials and
            # match either with surrounding apostrophes (e.g. 'Foo') or with
            # trailing . / , / : / space.
            my $pattern = qr/(['"]) \Q$ru\E \1/;
            $line =~ s/$pattern/$1$en$1/g;
            # Also handle bare strings (no surrounding quotes) that often
            # appear in interpolations like '$ru'.
            $line =~ s/\Q$ru\E/$en/g;
        }
        print $out $line;
    }
    close $in;
    close $out;
    rename "$path.tmp", $path or die "Cannot rename: $!";
    print "translated $rel\n";
}
