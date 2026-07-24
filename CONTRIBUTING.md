# Contributing to 7III Water

Thank you for helping make Water better. Contributions from riders, designers, translators, testers, and developers are welcome.

## Start with an issue

Before starting a substantial change, [open an issue](https://github.com/nilsmango/7III_Location_App/issues/new/choose) describing:

- the problem or opportunity;
- the water sport and workflow it affects;
- what a good result would feel like;
- any edge cases, screenshots, session examples, or devices that matter.

Small fixes can go directly to a pull request. If you are unsure where to begin, browse the open issues and ask to take one.

## AI-assisted contributions are welcome

You may point an AI coding assistant at this repository and ask it to investigate an issue or implement a feature. You remain responsible for the contribution:

- understand the change before submitting it;
- do not send private workout data, signing credentials, or API keys to an AI service;
- review every generated line;
- build and test the affected app targets;
- explain what you tested in the pull request.

## Development workflow

1. Fork the repository and create a focused branch.
2. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig`. Keep real keys local.
3. Open `7III Tracker.xcodeproj` and use the `7III Tracker` scheme.
4. Follow the existing Swift and SwiftUI style in the files you touch.
5. Add or update tests when behavior changes.
6. Test on the relevant iPhone, Apple Watch, and OS versions where practical.
7. Open a pull request that links its issue and clearly describes the user-facing change.

Keep pull requests small enough to review. Avoid unrelated formatting or generated-project-file changes.

Screenshot export tests write to a temporary folder by default. Set the `WATER_SCREENSHOT_OUTPUT` environment variable when you want them written somewhere specific.

## Good pull requests include

- a concise explanation of the problem and solution;
- screenshots or a short recording for interface changes;
- exact test steps and results;
- accessibility and localization considerations;
- no secrets, personal health data, or unrelated files.

By submitting a contribution, you agree to license it under the Mozilla Public License 2.0 so the covered source and its modifications remain open for the community.
