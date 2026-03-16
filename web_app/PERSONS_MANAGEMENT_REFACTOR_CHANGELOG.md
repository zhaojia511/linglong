# Change Log: Person Data Loading Refactor (2026-01-06)

## Summary
- Refactored `PersonsManagement` page to fetch person data directly from Supabase using `personService.getPersons()`.
- Removed reliance on the legacy `/api/persons` endpoint, which is not connected to Supabase and may not exist in the backend.
- This ensures the web app always loads the latest person data from the Supabase database, matching the mobile app sync logic.

## Impact
- Person data in the web app is now always up-to-date and consistent with the mobile app.
- No more dependency on a custom backend API for person data.

## Files Changed
- `web_app/src/pages/PersonsManagement.jsx`

## Verification
- No errors found after refactor.
- All environment variables for Supabase are present and correct.

---
Automated by GitHub Copilot on 2026-01-06.
