# Change History

## 2025-12-25
- Added hexagonal architecture structure with domain, application, and adapters.
- Centralized playlist URL in config.
- Expanded unit tests for adapters and application service.
- Added this change history file and referenced it from AGENTS.md.
- Redesigned the Android TV home UI with a TV-friendly layout and focusable cards.
- Split Android TV home UI into dedicated layout/widgets to keep Home focused.
- Added a TV-friendly startup loading screen and removed the LIVE badge from the player overlay.
- Adjusted TV navigation rail, moved version/flavor info, and added TV-styled manage/add dialogs.
- Refactored Home into controller/state with atomic widgets and TV-specific subfolders.
- Mirrored TV UI/UX on web, added responsive compact layout, and enabled mouse interaction.
- Added a web loading screen with logo in `web/index.html`.
- Bumped app version to 2.2.1+15 for new debug APK builds.
- Synced `assets/all_channels_available.yml` with the remote playlist and aligned display casing with filtered names.
- Updated the Android splash to avoid white startup screens and centered the app icon.
- Refactored the TV add-channels dialog to avoid framework assertions and added a close-flow test.
