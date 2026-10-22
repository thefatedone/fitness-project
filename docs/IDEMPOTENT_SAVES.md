# Prevent duplicate diary saves

## Behavior

The mobile client assigns one UUID to a save attempt and persists it before sending.
Retries reuse that UUID and the exact original payload, including its timestamp.
Food, water, weight, recognized single foods, recognized beverages and confirmed
manual beverages now use this path. Whole multi-ingredient dishes already have an
independent persisted UUID and atomic-save contract (`SAVED_MEALS.md`).

- Double taps while saving are blocked in the provider, save coordinator and forms.
  Quick water buttons additionally suppress accidental taps within 500 ms using a
  monotonic clock, including when a local server responds before the second tap.
- Losing a response or restarting the app retains the pending operation in the
  existing account/API-scoped recovery store. The diary shows **Check save**.
- JSON retries preserve their original date/time. A changed form cannot overwrite
  an uncertain attempt: resolve the earlier save first. New saves after confirmation
  get new IDs, so two intentional identical portions/glasses remain possible.
- A pending photo keeps its SHA-256 byte hash and query parameters, not a photo copy.
  Selecting the same image again (even under another filename) reuses the original
  ID. **Check save** can retrieve an already committed result without uploading or
  invoking AI. If no result is confirmed yet, select the original photo again.
  A suggestion-only beverage result similarly needs the original photo selected
  again to reopen its confirmation form; it does not create diary rows by itself.
- Completed responses are decoded and checked before clearing the attempt. Local
  storage errors stop new requests. Different types of pending saves update their
  shared persistent list serially; an account/environment change invalidates late
  responses and never transfers requests to the new account.
- A retry whose saved food/water/weight rows were subsequently deleted returns 410;
  it does not recreate them or put a cached deleted row back into the diary.

This identifies a repeated request, not semantically similar meals. Different
photos or a deliberate new action after confirmation are separate saves. No
nutrition/date heuristic silently removes legitimate repeated portions.

## Backend

Migration `0006_save_operations` adds `save_operations` with a composite primary key
`(user_id, key)`, request route/fingerprint, cached response, referenced resources and
creation time. It was applied to the local OrbStack database only.

`Idempotency-Key: <UUID>` is supported on:

- `POST /api/v1/tracker/food`, `/water`, `/weight`
- `POST /api/v1/food/recognize-and-log`, `/recognize-beverage`, `/log-beverage-manual`

The `idempotent_save` transaction boundary reserves the key before executing a
handler, then commits diary rows and the replay response together. Decorated handlers
flush rather than commit. Concurrent duplicate inserts wait on the same primary key;
after the first commit, duplicates return its cached response and do not call AI or
write more rows. Failure rolls back both data and the receipt.

A changed body or route under the same key returns 409. Keys and lookup are scoped
to the authenticated owner. `GET /api/v1/tracker/saves/{key}` returns a confirmed
response (404 means not confirmed yet, including a still-running transaction; 410
means a referenced row was deleted). Photo fingerprints use image bytes, independent
of multipart boundaries and filename. Receipt rows currently remain until account
deletion, which cascades through their user foreign key.

Older clients/web requests without the header retain their previous behavior.
They must adopt a stable per-attempt header to gain this guarantee. Read-only photo
analysis and text reanalysis of an existing row do not create new diary rows and are
not wrapped in this save boundary.

## Verification

- `backend/tests/test_idempotent_saves.py`: each create path, replay IDs/results,
  separate intentional repeats, changed payload/route, owner isolation, deleted
  resources, invalid keys, rollback, AI-result reuse and beverage pair consistency.
  AI is stubbed and database fixtures are disposable, with TEST_DATABASE_URL enabled.
- `flutter_app/test/save_coordinator_test.dart`: lost response + restart, original
  timestamp, changed forms, failed storage, rapid taps, concurrent save types,
  malformed responses, photo rename/hash, deleted resources, account separation,
  and narrow RU/EN/KA layouts with large text.
- Migration and six concurrent requests for each save route were checked on a
  temporary PostgreSQL database, then removed: one saved result per key and exactly
  one AI call per photo. No external AI requests were made during verification.
