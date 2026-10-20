# NutriMind project context

- `backend/`: FastAPI, async SQLAlchemy, Alembic, Python. `nutrimind/`: Next.js 16, React, TypeScript. `flutter_app/`: Flutter/Dart mobile app.
- Read `README.md` for setup and `ORBSTACK.md` for local container workflows when those topics are relevant. Check the actual source and scripts when documentation differs.
- There may be substantial user work in progress: inspect the relevant diff and preserve unrelated changes.

## Focused verification

- Backend: from `backend/`, use the project's Python environment and `python -m pytest` with affected test paths. `pyproject.toml` configures async tests.
- Backend `tests/conftest.py` requires `TEST_DATABASE_URL` pointing to a separate disposable database and rejects the live `DATABASE_URL`. Confirm the target before running tests; do not substitute the application database or bypass the guard.
- Web: from `nutrimind/`, `npm run lint`; use `npm run build` for changes affecting compilation, routes, or framework integration. Follow `nutrimind/AGENTS.md` for the installed Next.js version.
- Mobile: from `flutter_app/`, use `flutter analyze` and affected `flutter test` targets when applicable.
- Scope checks to changed behavior; configuration/documentation-only changes do not require starting the full stack.

## Local operations

- Use existing lockfiles and package managers. Prefer installed project dependencies over global replacements.
- `make help` lists container operations. `make clean` deletes database/upload volumes; `make prune` removes Docker resources. Run these only with explicit authorization for deletion.
- Keep credentials in local environment files; never print or commit their values. Database migrations and external AI calls need task-specific consideration of the target and side effects.
