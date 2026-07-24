<div>

[**简体中文**](README_zh_CN.md)

</div>

# FlClash Patched

[![Downloads](https://img.shields.io/github/downloads/chenx-dust/FlClash-Patched/total?style=flat-square&logo=github)](https://github.com/chenx-dust/FlClash-Patched/releases/)[![Last Version](https://img.shields.io/github/release/chenx-dust/FlClash-Patched/all.svg?style=flat-square)](https://github.com/chenx-dust/FlClash-Patched/releases/)[![License](https://img.shields.io/github/license/chenx-dust/FlClash-Patched?style=flat-square)](LICENSE)

A soft fork of [FlClash](https://github.com/chen08209/FlClash), with several bug fixes, power efficiency improvements and new features.

## Features

- Enhanced security (privileged behavior boundary restrictions, IPC security enhancements)
- Support iOS platform (requires an Apple Developer account to build)
- Optimized experience on Linux (Pacman package distribution, fixed RPM dependencies, WM_CLASS issues)
- Fixed bugs from upstream (startup time, window positioning, notifications)
- Energy efficiency optimizations (improved Android Doze, unified UI timer suspend)
- UI optimizations (proxy selection, log and connection filtering/sorting)
- New features (Age-Key encryption support, Windows high-priority startup)

For more information, please check the details in [Applied Patches (#1)](https://github.com/chenx-dust/FlClash-Patched/issues/1)

# Original Introduction

A multi-platform proxy client based on mihomo, simple and easy to use, open-source and ad-free.

## Features

✈️ Multi-platform: Android, iOS, Windows, macOS and Linux

💻 Adaptive multiple screen sizes, Multiple color themes available

💡 Based on Material You Design, [Surfboard](https://github.com/getsurfboard/surfboard)-like UI

☁️ Supports data sync via WebDAV

✨ Support subscription link, Dark mode

## Use

### Linux

⚠️ Make sure to install the following dependencies before using them

   ```bash
    sudo apt-get install libayatana-appindicator3-dev
    sudo apt-get install libkeybinder-3.0-dev
   ```

### Android

Support the following actions

   ```bash
    com.follow.clash.action.START
    
    com.follow.clash.action.STOP
    
    com.follow.clash.action.TOGGLE
   ```

## Download

<a href="https://github.com/chenx-dust/FlClash-Patched/releases"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="200px"/></a>

## Build

1. Update submodules
   ```bash
   git submodule update --init --recursive
   ```

2. Install `Flutter` and `Golang` environment

3. Build Application

    - android

        1. Install `Android SDK`, `Android NDK`

        2. Set `ANDROID_NDK` environment variable

        3. Run build script

           ```bash
           dart setup.dart android
           ```

    - windows

        1. Requires a Windows client

        2. Install `GCC`, `Inno Setup`

        3. Run build script

           ```bash
           dart setup.dart windows
           ```

    - linux

        1. Requires a Linux client

        2. Dependencies are auto-installed by setup script, or manually:
           ```bash
           sudo apt-get install -y libayatana-appindicator3-dev libkeybinder-3.0-dev
           ```

        3. Run build script

           ```bash
           dart setup.dart linux
           ```

    - macOS

        1. Requires a macOS client

        2. Run build script

           ```bash
           dart setup.dart macos
           ```

    - iOS

        1. Requires a macOS client

        2. Configure Apple Developer capabilities, App Group and provisioning profiles for the app bundle and Network Extension bundle

        3. Run build script

           ```bash
           dart setup.dart ios --ios-bundle-id com.example.flclash
           ```
