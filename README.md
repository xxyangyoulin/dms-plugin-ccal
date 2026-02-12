# Chinese Calendar for [DankMaterialShell](https://github.com/DankMaterialShell/DankMaterialShell)

![Screenshot](assets/screenshot.png)

Display Chinese lunar calendar (农历) with holiday information directly in your status bar.

## Features

- **Status Bar Widget**: Customizable display of Gregorian and Lunar dates.
- **Full Lunar Calendar**: Popup view showing lunar dates, solar terms (节气), and festivals.
- **Holiday Integration**: Real-time indication of holidays and make-up workdays (调休) sourced from `holiday-cn`.
- **Smart Navigation**: Scroll to change months, click to jump to specific dates, and quick return to "Today".
- **Detailed Info**: View detailed information for any selected date, including days until the next holiday.

## Requirements

- **System Package**: `ccal` is required for generating lunar calendar data.
- **System Package**: `curl` is required for fetching holiday definitions.
- Network connection for holiday data updates.

## Configuration

1. Go to Plugin Settings.
2. Customize the **Date Format** string (e.g., `ddd MM月dd日 LL`).
   - Supported tokens: `LL` (Lunar Date), `yyyy` (Year), `MM` (Month), etc.

## Install ccal

### Arch Linux / Manjaro
```bash
yay -S ccal
```

## Permissions

- `settings_read` / `settings_write`
- `process`
- `network`

## Credits

This project is based on and powered by:

- **[ccal](http://ccal.chinesebay.com/ccal/ccal.htm)**: Provides the core lunar calendar calculation engine.
- **[hodiday](https://github.com/tomandjerry136/hodiday)**: Provides the holiday arrangement data source.

## Feedback & Contributions

Suggestions for improvements and feature requests are always welcome.
If you have ideas, encounter issues, or want to see new features, feel free to open an issue or submit a pull request.