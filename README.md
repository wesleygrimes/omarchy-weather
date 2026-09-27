# Weather

Live weather on the [Omarchy](https://omarchy.org) bar. Click the pill for the forecast,
sunrise, sunset, moon phase, and animated rain radar.

## Install

```sh
omarchy plugin add https://github.com/wesleygrimes/omarchy-weather.git --enable
```

Move it with `omarchy bar move wesgrimes.weather --section right`.

Radar needs the native map packages:

```sh
omarchy pkg add maplibre-native-qt qt6-location
```

The popup's **Install map support** button opens the package installer in a terminal
and restarts the shell after installation succeeds. Weather, forecast, and astronomy
work without these packages. No browser, Python environment, or API key is required.

The map uses [OpenFreeMap](https://openfreemap.org/). Precipitation comes from
[RainViewer](https://www.rainviewer.com/) and shows the last available hour of radar
history. RainViewer's free API is for personal and educational use. The latest frame
is an observation, not a forecast; its time appears beside the playback controls.

## Remove

```sh
omarchy plugin remove wesgrimes.weather
```

## Development

From this directory, not the installed plugin:

```bash
mise format      # write JS
mise check       # tests, validate, fail if unformatted
mise dev         # install wesgrimes.weather-dev, reload on save, remove on exit
mise screenshot  # open the popup and save a PNG under tmp/
```

Conventions: [CONTRIBUTING.md](CONTRIBUTING.md). MIT: [LICENSE.md](LICENSE.md).

## Contributors

Thanks to these people
([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/wesleygrimes"><img src="https://avatars.githubusercontent.com/u/324308?v=4?s=100" width="100px;" alt="Wes Grimes"/><br /><sub><b>Wes Grimes</b></sub></a><br /><a href="https://github.com/wesleygrimes/omarchy-weather/commits?author=wesleygrimes" title="Code">💻</a> <a href="https://github.com/wesleygrimes/omarchy-weather/commits?author=wesleygrimes" title="Documentation">📖</a> <a href="#maintenance-wesleygrimes" title="Maintenance">🚧</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://allcontributors.org) specification.
