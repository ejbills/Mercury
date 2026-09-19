# Mercury

A SwiftUI Reddit client for iOS.

> **Archived.** This project is no longer maintained. The code is published as-is under the MIT license for anyone who wants to learn from it or fork it.

## Building

1. Open `Mercury.xcodeproj` in Xcode 26 or later (the deployment target is iOS 26).
2. Set your own signing team and bundle identifier.
3. Optional: to enable GIF search, copy `.env.example` to `.env` and add a [Giphy](https://developers.giphy.com) API key. A build phase generates `Mercury/Generated/Secrets.swift` from that file.

## Reddit API access

Mercury ships without a Reddit client ID. Each user creates their own **installed app** at <https://www.reddit.com/prefs/apps> with the redirect URI `mercury://oauth`, then pastes the client ID into the app during setup.

## License

[MIT](LICENSE)
