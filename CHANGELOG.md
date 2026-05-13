# Changelog

Each entry is appended by a relay engineer after completing one ticket.

## [2026-05-13] issue-24: We're missing a "light mode" theme
- Added CSS custom properties for light/dark theming; defaults to system `prefers-color-scheme`
- Added a theme toggle button in the app header that persists preference to `localStorage`
- Files changed: `frontend/src/styles.css`, `frontend/src/App.tsx`
