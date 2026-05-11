# 9Quoter

9Quoter is a native macOS menu bar app for tracking quota usage across 9router providers.

## Features

- Tracks quota usage by provider and account
- Groups accounts by provider
- Shows remaining quota, reset time, and account status
- Supports account enable/disable from the menu bar
- Stores auth data in macOS Keychain

## Requirements

- macOS Ventura 13.0 or newer
- A running 9router instance, defaulting to `http://localhost:20128`

## Install with Homebrew

```bash
brew tap hodtien/9quoter https://github.com/hodtien/9quoter
brew install --cask hodtien/9quoter/9quoter
```

Upgrade later with:

```bash
brew update
brew upgrade --cask hodtien/9quoter/9quoter
```

## Open the app

```bash
open -a 9Quoter
```

Or:

```bash
open /Applications/9Quoter.app
```

9Quoter runs as a menu bar app. After opening it, click the quota/chart icon in the macOS menu bar to show the panel.

## Build locally

```bash
cd 9QuoterApp
swift build
```

Build a release app bundle and zip:

```bash
./Packaging/build-release.sh
```

The release zip is written to `9QuoterApp/dist/`.
