# Water content locations

- In-app release notes: `7III Downwind/Model/VersionHistory.swift` in this repository.
- App Store metadata: `/Users/simxn/Documents/Geschäft/project7III/Apps/7III Water/Water App Store Metadata/Metadata/app-store-text-*.md` in a separate Git repository. The English file is the master; keep the App Store version aligned across locales. The metadata repository's `README.md` documents its format and upload scripts.
- Website: `/Users/simxn/Sites/project7iii.com` is a separate Zola repository. The public `/water` pages are sourced from `content/water/`, especially `_index.md` and `history.md`. Edit those source files; `public/water/` is generated output.

When changing Water's features or release history, check these locations for important text that needs updating. Keep descriptions concise and accurate; the wind direction analysis has a documented pending case in `TrackerScreenshotTests/WindRouteFixtures/Pending/`.
