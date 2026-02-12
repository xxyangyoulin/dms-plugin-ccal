# Chinese Calendar Widget for DankMaterialShell

DankMaterialShell status bar widget for Chinese lunar calendar. Display current lunar date in the status bar and click to reveal a full lunar calendar popup.

## Features

- **Status Bar Display**: Shows current lunar date (e.g., 十四、十五)
- **Popup Calendar**: Click the status bar icon to reveal the full lunar calendar
- **Date Grid**: Each date cell shows the corresponding lunar date below it
- **Month Navigation**: Browse through different months
- **Language Toggle**: Support for Simplified and Traditional Chinese
- **Customizable Options**: Configure icon, date format, and more

## Status Bar Display

Default format: `📅 2/11 十四`

## Popup Calendar

```
┌─────────────────────────────┐
│        农历日历              │
├─────────────────────────────┤
│  <    February 2026    >    │
│  Su Mo Tu We Th Fr Sa       │
│  ───────────────────────    │
│  1   2   3   4   5   6   7  │
│ 十四 十五 十六 ...           │
│  8   9  10  11  12  13  14  │
│ 廿一 廿二 廿三 ...           │
│  ...                        │
├─────────────────────────────┤
│   Year BingWu, Month 1D     │
│   今天是农历 十四            │
└─────────────────────────────┘
```

## Requirements

- **System Package**: `ccal` command is required for lunar calendar data
- **System Package**: `curl` command is required for fetching holiday information

## Configuration

1. Go to Plugin Settings
2. Customize display options:
   - Show/Hide icon
   - Show/Hide Gregorian date
   - Show/Hide lunar date
   - Date format (M/D, M月D日, MM/DD)
   - Character type (Simplified/Traditional)

## Install ccal

### Arch Linux / Manjaro
```bash
yay -S ccal
```

### Debian / Ubuntu
```bash
sudo apt install ccal
```

### Fedora
```bash
sudo dnf install ccal
```

## Permissions

- `settings_read` / `settings_write`
- `process` - For executing ccal command
- `network` - For fetching holiday data
