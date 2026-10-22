# Undo deletion and network recovery

## User behavior

- Deleting a food entry, a whole dish/selected ingredients, or a water entry offers
  **Undo** for 10 seconds after confirmation. The snackbar sits above the dock.
- A failed or lost delete response leaves the original entries visible with an
  explicit unconfirmed status. **Retry** reuses the operation ID; **Undo** cancels
  that same operation, even if the server already committed it.
- An offline undo restores the originals locally immediately after persisting the
  intent. The diary shows that server restoration is still pending. Use **Retry**
  once the server is reachable. Pending operations survive app restart; they are
  not blindly replayed as new deletions in the background.
- The previously loaded food/water diary is cached by calendar day. An unavailable
  server shows this cache with a status notice. An uncached day stays empty rather
  than displaying another day's entries. Late responses cannot overwrite a newer
  date or a different signed-in account.
- Before sending a reviewed multi-ingredient meal, the exact draft (including its
  save UUID and selected date) is stored locally. After a failed save or restart,
  **Open meal** on the diary resumes that same save. A second save cannot overwrite
  an unresolved draft. Confirmed rows are cached before the draft is cleared.
- Recovery storage is scoped to the authenticated account AND API base URL.
  It uses the existing SharedPreferences dependency; it contains nutrition/cache
  data, not tokens. Store operations are serialized per namespace. If writing a
  deletion snapshot fails, no destructive request is sent.

Additional per-attempt protection for all diary save paths is documented in
`IDEMPOTENT_SAVES.md`. This is read-cache and explicit retry support, not a general
offline creation queue.
Manual food, water and weight forms retain their current in-memory values when a
request fails, as before; their unfinished form fields are not restored after app
termination. Photo files and scan results before tapping Save are not durable drafts.

## Backend contract

Migration `0005_diary_deletions` adds owned receipts with a selection, original row
snapshots and a terminal state. Apply it before using the new mobile client. It was
applied only to the local OrbStack database during implementation.

`POST /api/v1/tracker/diary/deletion` accepts:

```
{"id":"client-generated-UUID","food_ids":["id"],"water_ids":[],"restore":false}
```

`restore:true` uses exactly the same ID and selection. A unique receipt plus a
transactional row lock serializes delete/undo and concurrent retries. All selected
rows must belong to the caller; otherwise the transaction changes nothing. Restore
keeps original IDs, timestamps, macros, AI provenance and dish grouping. Cancel can
arrive before a delayed delete; the restored state suppresses that delete permanently.
The receipt response is `{id,state}`, with state `deleted` or `restored`. Reusing an
ID for another selection returns 409; using another user's receipt returns 404.
Legacy hard-delete endpoints remain available for older clients and web compatibility.
Receipts currently remain until account deletion (cascading user FK); there is no
scheduled trash cleanup or user-facing permanent-trash browser in this change.

## Verification

- `backend/tests/test_diary_deletion.py`: whole selection undo, repeat calls,
  original-field preservation, cancellation before deletion, ownership, conflicting
  selections, and rollback/retry after storage failure. Uses the disposable fixture
  from `test_saved_meals.py`, with the repository TEST_DATABASE_URL guard enabled.
- `flutter_app/test/diary_recovery_test.dart`: response loss, offline undo and restart,
  failed local storage, rapid taps, cache isolation, late date/account responses,
  draft persistence, undo expiry, committed-meal caching and RU/EN/KA accessibility.
- Migration and simultaneous deletes/restores were also verified against a temporary
  PostgreSQL database, removed after the checks. Existing diary rows were preserved.
