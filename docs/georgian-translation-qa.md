# Georgian Translation QA Checklist

## Overview

This checklist verifies the English ↔ Georgian (EN ↔ ქარ) language switch in NutriMind across all pages and components.

**Test account:** `demo@nutrimind.com` / `demo123`  
**Base URL:** http://localhost:3000  
**Backend API:** http://localhost:8000

---

## Pre-Checks

- [ ] Log in to NutriMind with demo credentials
- [ ] Confirm language is initially set to **EN**
- [ ] Open browser DevTools → Application → Local Storage → verify `nutrimind_lang` key exists

---

## 1. Language Switcher — Sidebar

- [ ] LanguageSwitcher (EN / ქარ buttons) renders in the bottom-left sidebar above Logout on all 4 pages
- [ ] Active language button is highlighted in green (`#22c55e`)
- [ ] Inactive language button has muted white text (`text-white/70`)
- [ ] Switcher is present on `/dashboard/tracker`
- [ ] Switcher is present on `/dashboard/meals`
- [ ] Switcher is present on `/dashboard/assistant`
- [ ] Switcher is present on `/dashboard/profile`
- [ ] Switcher is present on mobile bottom nav

---

## 2. Language Switching — UI Text

- [ ] Click **ქარ** — all sidebar nav labels switch to Georgian immediately (no page reload)
- [ ] Click **EN** — all sidebar nav labels switch back to English immediately (no page reload)
- [ ] Switching language does NOT trigger a full page reload
- [ ] Transition is smooth (no flash of untranslated text)

---

## 3. Georgian Font Rendering

- [ ] Navigate to `/dashboard/tracker` in Georgian mode — page title "დღიური თრექერი" renders in Noto Sans Georgian
- [ ] Navigate to `/dashboard/meals` in Georgian mode — page title "კვების გეგმი" renders correctly
- [ ] Navigate to `/dashboard/assistant` in Georgian mode — subtitle "შენი პირადი კვების მწვრთნელი" renders correctly
- [ ] Navigate to `/dashboard/profile` in Georgian mode — section headers render in Georgian script
- [ ] Landing page hero "იკვებე სწორად. იცხოვრე უკეთ. აკონტროლე მარტივად." renders correctly
- [ ] No broken glyphs or fallback fonts visible for Georgian text
- [ ] Georgian text does not overflow or clip in narrow containers

---

## 4. Language Persistence (localStorage)

- [ ] Switch to Georgian, close the browser tab, reopen and navigate to any dashboard page — language is still Georgian
- [ ] Verify `nutrimind_lang` value in DevTools is `ka` after switching to Georgian
- [ ] Verify `nutrimind_lang` value in DevTools is `en` after switching to English
- [ ] Verify `document.documentElement.lang` attribute is `ka` when Georgian is active
- [ ] Verify `document.documentElement.lang` attribute is `en` when English is active

---

## 5. All 4 Pages — Full Translation Coverage

### `/dashboard/tracker`
- [ ] "Daily Tracker" → "დღიური თრექერი"
- [ ] "Macronutrients" → "მაკრონუტრიენტები"
- [ ] "Protein" / "Carbohydrates" / "Fat" → "ცილები" / "ნახშირწყლები" / "ცხიმები"
- [ ] "Meals" → "კვება"
- [ ] "Breakfast" / "Lunch" / "Dinner" / "Snack" → "საუზმე" / "სადილი" / "ვახშამი" / "ჩალამური"
- [ ] "No items yet" → "პროდუქტები არ არის"
- [ ] "+ Add food" → "+ დამატება"

### `/dashboard/meals`
- [ ] "Meal Planner" → "კვების გეგმი"
- [ ] "Plan and track your weekly nutrition" → "დაგეგმე და აკონტროლე შენი კვირის კვება"
- [ ] "Log Food by Photo" → "კვების ფოტოთი აღრიცხვა"
- [ ] "No foods logged" → "კვება არ არის ჩაწერილი"
- [ ] "+ Add Food" → "+ დამატება"
- [ ] "AI Meal Suggestions" → "AI კერძების შემოთავაზებები"
- [ ] "Your Daily Targets" → "შენი დღიური მიზნები"
- [ ] "kcal base" / "protein" → "კკალ ბაზა" / "ცილები"
- [ ] "Bulk / Mass" → "მასის მომატება"
- [ ] "+15% calories" → "+15% კალორია"
- [ ] "Cut / Deficit" → "დეფიციტი"
- [ ] "-25% calories" → "-25% კალორია"
- [ ] "Opens AI Assistant with your meal plan" → "გახსნის AI ასისტენტს შენი კვების გეგმით"

### `/dashboard/assistant`
- [ ] "NutriMind AI" → "NutriMind AI" (brand name stays English)
- [ ] "Your personal nutrition coach" → "შენი პირადი კვების მწვრთნელი"
- [ ] "How can I help you today?" → "რით შემიძლია დახმარება დღეს?"
- [ ] Context paragraph → "ვიცი შენი კვების მიზნები და დღევანდელი მიღებული საკვები..."
- [ ] "Ask your nutrition coach..." → "ჰკითხე შენს კვების მწვრთნელს..."
- [ ] "Clear chat" → "ჩათის გასუფთავება"
- [ ] Quick suggestion chips (4) render in Georgian

### `/dashboard/profile`
- [ ] "My Profile" → "ჩემი პროფილი"
- [ ] "Personal Information" → "პირადი ინფორმაცია"
- [ ] "Full Name" / "Email" / "Date of Birth" / "Sex" → "სახელი გვარი" / "ელფოსტა" / "დაბადების თარიღი" / "სქესი"
- [ ] "Male" / "Female" / "Prefer not to say" → "მამრობილი" / "მდედრობილი" / "არ მინდა განსაზღვრა"
- [ ] "Save Changes" → "ცვლილებების შენახვა"
- [ ] "Measurements" → "გაზომვები"
- [ ] "Height (cm)" / "Current Weight (kg)" / "Target Weight (kg)" → "სიმაღლე (სმ)" / "მიმდინარე წონა (კგ)" / "სამიზნე წონა (კგ)"
- [ ] "Activity Level" → "აქტივობის დონე"
- [ ] "Lightly Active" → "მსუბუქად აქტიური"
- [ ] "Weight Goal Pace" / "kg/week" → "წონის მიზნის ტემპი" / "კგ/კვირა"
- [ ] "Save & Recalculate" → "შენახვა და ხელახლა გამოთვლა"
- [ ] "Dietary Preferences" → "კვებითი პრეფერენციები"
- [ ] "Primary Goal" → "მთავარი მიზანი"
- [ ] "Your Daily Targets" → "შენი დღიური მიზნები"
- [ ] "Calculated from your profile" → "გამოთვლილია შენი პროფილიდან"
- [ ] "Calories kcal" / "Protein" / "Carbs" / "Fat" → "კალორია კკალ" / "ცილები" / "ნახშირწყლები" / "ცხიმები"
- [ ] "BMI" → "BMI"
- [ ] "Obese" (BMI category) → "მსუქრი"
- [ ] "BMR (base)" / "TDEE (with activity)" → "BMR (ბაზა)" / "TDEE (აქტივობით)"
- [ ] "kcal/day" → "კკალ/დღე"
- [ ] "Targets update automatically when you save measurements" → "მიზნები ავტომატურად განახლდება გაზომვების შენახვისას"
- [ ] "Weight Progress" → "წონის პროგრესი"
- [ ] "Start logging your weight to see progress" → "დაიწყე წონის აღრიცხვა პროგრესის სანახავად"
- [ ] "Log" button → "ჩაწერე"

---

## 6. Dynamic / Numeric Values Remain Unchanged

- [ ] Tracker: calorie numbers (e.g. `1,450 / 2,000 kcal`) stay numeric
- [ ] Tracker: macro grams (e.g. `120g protein`) stay numeric
- [ ] Tracker: water intake (e.g. `1,500 ml`) stays numeric
- [ ] Tracker: date navigation shows correct dates (Georgian locale format acceptable but not required)
- [ ] Meals: week strip dates stay numeric
- [ ] Meals: calorie totals per meal stay numeric
- [ ] Profile: BMI score (e.g. `24.8`) stays numeric — only label translates
- [ ] Profile: BMR / TDEE numbers stay numeric
- [ ] Profile: weight values (kg) stay numeric
- [ ] Profile: height values (cm) stay numeric
- [ ] Profile: daily calorie/protein/carbs/fat targets stay numeric

---

## 7. AI Assistant — Language Response

### With EN active:
- [ ] Send "What should I eat for lunch?" → AI responds in English
- [ ] Send "Analyze today's nutrition" → AI responds in English
- [ ] Send a free-form nutrition question → AI responds in English

### With ქარ active:
- [ ] Send "რა შემიძლია სადილად?" → AI responds in Georgian
- [ ] Send "გაანალიზე დღევანდელი კვება" → AI responds in Georgian
- [ ] Send a free-form nutrition question in Georgian → AI responds in Georgian
- [ ] Quick suggestion chips in Georgian mode → clicking a chip sends Georgian text to AI → AI responds in Georgian

---

## 8. Layout Integrity with Georgian Text

- [ ] Sidebar nav links: "თრექერი", "კვება", "AI ასისტენტი", "პროფილი" — all fit within sidebar width without overflow
- [ ] "გასვლა" (Logout) button fits in sidebar
- [ ] Profile: goal chips (მასის მომატება, დეფიციტი) — fit within card width
- [ ] Profile: dietary preference labels — no text clipping
- [ ] Meals: "კვების ფოტოთი აღრიცხვა" button fits without overflow
- [ ] Meals: "AI კერძების შემოთავაზებები" section header fits
- [ ] Meals: "გახსნის AI ასისტენტს შენი კვების გეგმით" helper text fits
- [ ] Assistant: "ჰკითხე შენს კვების მწვრთნელს..." placeholder fits in input
- [ ] Assistant: quick chip text wraps gracefully at 2 lines max
- [ ] No horizontal scrollbars appear due to translated text overflow

---

## 9. Edge Cases

- [ ] Switch to Georgian, hard-refresh page (Ctrl+Shift+R) → language persists
- [ ] Switch to Georgian, open a new tab to the same URL → language is Georgian
- [ ] Login page (unauthenticated) — no errors in console
- [ ] No `i18next` console errors about missing translation keys
- [ ] `lang` attribute on `<html>` updates correctly (check via DevTools Elements panel)
- [ ] All 4 pages load without crashing when language is set to `ka` on first load

---

## 10. Regression Checks

- [ ] All sidebar navigation links still work (clicking routes to correct page)
- [ ] Logout button still works
- [ ] CalorieRing and MacroBar components still render with numeric data
- [ ] AddFoodModal opens and closes correctly on tracker and meals pages
- [ ] Water tracker quick-add buttons (250ml, 500ml) keep numeric values
- [ ] AI chat streaming still works (response streams in real-time)
- [ ] No JavaScript errors in console on any page after switching languages

---

## Notes

- Georgian translation keys are defined in `src/i18n/locales/ka/translation.json`
- i18next is initialized in `src/i18n/index.js` with `nutrimind_lang` localStorage key
- Language is synced to `<html lang="...">` via `i18n.on('languageChanged')` listener
- Font is applied via CSS rule `html[lang="ka"] body { font-family: 'Noto Sans Georgian' }`
- AI language instruction is prepended to every user message in `AssistantPage.sendMessage()`
