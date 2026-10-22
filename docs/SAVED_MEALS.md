# Whole dishes and repeat logging

The mobile multi-ingredient flow is now: scan → review → name the dish → correct
ingredients/portions → save the complete dish → repeat from the diary or **My meals**.

- Tap an ingredient to expand it. The portion stepper rescales its nutrition.
  **Edit ingredient** changes its name, weight and portion totals. Changing weight
  there also rescales nutrition. Renaming alone does not look up different nutrition
  or make another AI call; correct the values when replacing a different food.
- Add missed ingredients manually; remove unwanted ones before saving.
- Select breakfast, lunch, dinner or snack. Saving uses the diary's selected local
  calendar day, including when a recipe originally came from another day.
- A named dish is one expandable diary entry, with ingredient details, repeat and
  whole-dish deletion actions. Daily nutrition still sums the underlying ingredients
  exactly once. Unrelated food entries remain independent.
- **My meals** is available in the diary and manual-add screen. It displays distinct
  recipes from the 30 most recent saved snapshots (not a complete favorites library).
  Repeating opens a new editable copy. The original recipe and diary day stay intact.
- Deleting diary ingredients does not delete the saved recipe. Account deletion
  cascades to snapshots. Existing diary rows are not guessed into groups: they have
  no reliable dish identity. Individual/manual and beverage flows remain compatible.

## Persistence

Migration `0004_saved_meals` follows `0003_garden_days`: `saved_meals` holds an immutable
JSON snapshot and owner; nullable `food_logs.meal_id`/`meal_name` identify the dish.
No legacy diary data is rewritten. `POST /api/v1/tracker/meals` validates all ingredients
and commits snapshot, food rows and garden credit together. `GET /api/v1/tracker/meals`
returns only the authenticated user's snapshots, newest first, default limit 30.

The client generates a UUID for each new save. Retrying an uncertain save reuses
both the UUID and the exact payload; the server returns existing rows. A changed
payload under an existing ID returns 409, another owner's ID returns 404. Concurrent
saves meet the snapshot primary key before inserting ingredients. Retrying a deleted
diary dish never resurrects its deleted ingredients. A deliberate repetition gets a
new UUID. During an uncertain save the editor is frozen while Save remains available
for retry. The exact draft is persisted before sending and can be resumed after app
termination from the diary recovery notice; see `DIARY_RECOVERY.md`.

The user-confirmed ingredients use `ai_generated=False`: the old text-only AI reanalysis
endpoint must not independently rewrite one ingredient of a named dish.

## Schema rollout

Apply `alembic upgrade head` before serving the updated backend to an existing database.
`Base.metadata.create_all` cannot add these columns to an existing `food_logs` table.
The local OrbStack database was upgraded on 2026-10-21. Its previously created garden
schema was verified (columns, composite PK and cascading user FK) and its migration
revision reconciled from 0002 to 0003 before applying 0004. No production deployment
was performed. Do not stamp other databases unless their schema has been verified.

## Verification

`backend/tests/test_saved_meals.py` covers save, retry, independent edited repetitions,
owner isolation, library retention after deletion, conflicting requests, validation,
and rollback after database errors. Each fixture uses a disposable in-memory database;
run with the repository's `TEST_DATABASE_URL` guard enabled and distinct from the live DB.

`flutter_app/test/saved_meal_test.dart` covers model round trips, proportionate nutrition,
validation, one-request meal saving and retry, selected date, grouped diary actions,
and narrow layouts with large text in RU/EN/KA.
