# Project: iOS App

## App Name
- **表示名（CFBundleDisplayName / CFBundleName）**: PDF One
- **Xcodeプロジェクト/ターゲット/スキーム名**: PDF_One（表示名「PDF One」と統一。旧名MyFirstAppから2026-08-11にリネーム）

## Tech Stack
- iOS 17.0+ / SwiftUI / Swift Concurrency
- Architecture: MVVM (`@Observable`)
- Data: SwiftData / `Codable`
- Dependency: Swift Package Manager (SPM)

## Commands
- **Build**: `xcodebuild -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 15' build`
- **Test**: `xcodebuild -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 15' test`
- **Format**: `swiftformat .`

## Directory Structure
- `Sources/App/`: App entry point
- `Sources/Views/`: SwiftUI Views
- `Sources/ViewModels/`: `@Observable` ViewModels
- `Sources/Models/`: SwiftData models

## Coding Conventions
- Use `@Observable` macro for ViewModels.
- Keep SwiftUI views modular; limit individual view files to < 150 lines.

## Interaction Guidelines
- Output format: Code diffs/files first, minimal bullet-point explanation after.
- Do NOT explain basic Swift/SwiftUI syntax unless explicitly requested.
