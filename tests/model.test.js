const assert = require("assert");
const weather = require("../Model.js");

function equal(actual, expected, message) {
  assert.deepStrictEqual(actual, expected, message);
}

equal(
  weather.parseSavedLocation('{"name": "Malibu", "latitude": 34.02577, "longitude": -118.7804}\n'),
  {
    name: "Malibu",
    latitude: 34.02577,
    longitude: -118.7804,
  },
  "parses name plus coordinates"
);
equal(
  weather.parseSavedLocation('{"name": "New York"}'),
  {
    name: "New York",
    latitude: null,
    longitude: null,
  },
  "parses a name-only location"
);
equal(
  weather.parseSavedLocation("not json"),
  weather.emptyLocation(),
  "treats unparseable location as empty"
);

equal(
  weather.locationQuery({
    name: "Malibu",
    latitude: 34.02577,
    longitude: -118.7804,
  }),
  "34.02577,-118.7804",
  "prefers coordinates"
);
equal(
  weather.locationQuery({ name: "New York", latitude: null, longitude: null }),
  "New%20York",
  "encodes a name-only location"
);
equal(weather.locationQuery(weather.emptyLocation()), "", "empty location is auto-detect");
assert.strictEqual(
  weather.hasCoordinates({ latitude: 36.2, longitude: -79.9 }),
  true,
  "saved coordinates count"
);
assert.strictEqual(
  weather.hasCoordinates(weather.emptyLocation()),
  false,
  "empty location has no coordinates"
);

equal(
  weather.parseDetectedPlaceName("Stokesdale, North Carolina, United States"),
  "Stokesdale",
  "takes the city from a detected place"
);
equal(weather.parseDetectedPlaceName("  "), "", "ignores a blank detected place");

equal(
  weather.forecastCoordinates({ latitude: 36.237, longitude: -79.98 }, null),
  { latitude: 36.237, longitude: -79.98 },
  "uses the saved location"
);
equal(
  weather.forecastCoordinates(weather.emptyLocation(), {
    nearest_area: [{ latitude: "36.237", longitude: "-79.980" }],
  }),
  { latitude: 36.237, longitude: -79.98 },
  "falls back to the conditions area"
);
equal(
  weather.forecastCoordinates(weather.emptyLocation(), {}),
  null,
  "needs a location or a conditions area"
);

const conditions = {
  current_condition: [
    {
      temp_C: "26",
      temp_F: "80",
      FeelsLikeC: "27",
      FeelsLikeF: "81",
      windspeedKmph: "10",
      windspeedMiles: "6",
      humidity: "60",
      weatherCode: "176",
    },
  ],
  nearest_area: [
    {
      areaName: [{ value: "Stokesdale" }],
      country: [{ value: "United States of America" }],
      latitude: "36.237",
      longitude: "-79.980",
    },
  ],
  weather: [
    {
      date: "2026-09-19",
      maxtempC: "29",
      mintempC: "20",
      maxtempF: "84",
      mintempF: "67",
      astronomy: [
        {
          sunrise: "07:06 AM",
          sunset: "07:21 PM",
          moonrise: "03:28 PM",
          moonset: "No moonset",
          moon_phase: "Waxing Gibbous",
          moon_illumination: "51",
        },
      ],
      hourly: [{ time: "1200", weatherCode: "176" }],
    },
    {
      date: "2026-09-20",
      maxtempC: "31",
      mintempC: "20",
      maxtempF: "88",
      mintempF: "68",
      astronomy: [
        {
          sunrise: "07:07 AM",
          sunset: "07:19 PM",
          moon_phase: "Waxing Gibbous",
          moon_illumination: "61",
          moonrise: "04:10 PM",
          moonset: "12:30 AM",
        },
      ],
      hourly: [{ time: "1200", weatherCode: "176" }],
    },
  ],
};

const forecast = {
  current: {
    temperature_2m: 27.7,
    apparent_temperature: 31.6,
    relative_humidity_2m: 69,
    wind_speed_10m: 6.6,
    weather_code: 1,
    is_day: 1,
  },
  daily: {
    time: ["2026-09-19", "2026-09-20", "2026-09-21"],
    weather_code: [45, 65, 82],
    temperature_2m_max: [29.9, 32.7, 34.2],
    temperature_2m_min: [20.8, 21.0, 18.6],
  },
};

const stokesdale = { name: "Stokesdale", latitude: 36.237, longitude: -79.98 };

const pinned = weather.buildView({
  location: stokesdale,
  detectedPlaceName: "",
  conditions: conditions,
  forecast: forecast,
  unit: "",
  locale: "en_US",
  today: "2026-09-19",
});

assert.ok(pinned, "builds a view from both documents");
equal(pinned.location.name, "Stokesdale", "uses the saved location name");
equal(pinned.units, "imperial", "prefers the reported imperial country");
equal(pinned.current.temperature, "82", "a pinned location uses forecast for current");
equal(pinned.current.unit, "°F", "formats the current unit");
equal(
  pinned.forecast.map(function (day) {
    return day.date;
  }),
  ["2026-09-20", "2026-09-21"],
  "forecast skips today"
);
equal(pinned.forecast[0].high, "91°", "formats the forecast high");
equal(pinned.forecast[0].weekday, "SUNDAY", "names the forecast weekday");
equal(pinned.sun.sunrise, "07:06 AM", "reads sunrise from conditions");
equal(pinned.moon.phase, "Waxing Gibbous", "reads moon phase from conditions");
equal(pinned.moon.set, null, "treats no moonset as missing");

const nextDay = weather.buildView({
  conditions: conditions,
  today: "2026-09-20",
});
equal(
  nextDay.sun,
  { sunrise: "07:07 AM", sunset: "07:19 PM" },
  "selects today's sun times from a retained report"
);
equal(
  nextDay.moon,
  {
    phase: "Waxing Gibbous",
    illumination: "61%",
    rise: "04:10 PM",
    set: "12:30 AM",
  },
  "selects today's moon data from a retained report"
);

const missingDay = weather.buildView({
  conditions: conditions,
  today: "2026-09-21",
});
equal(missingDay.sun, { sunrise: "", sunset: "" }, "does not substitute another day's sun times");
equal(
  missingDay.moon,
  { phase: "", illumination: "", rise: null, set: null },
  "does not substitute another day's moon data"
);

const locationOnly = weather.buildView({ location: stokesdale });
equal(
  locationOnly.location.name,
  "Stokesdale",
  "keeps the saved location editable before weather succeeds"
);
equal(locationOnly.current, null, "does not invent current conditions before weather succeeds");
equal(locationOnly.forecast, [], "does not invent a forecast before weather succeeds");

const conditionsOnly = weather.buildView({
  location: stokesdale,
  conditions: conditions,
  unit: "",
  locale: "en_US",
  today: "2026-09-19",
});
assert.notStrictEqual(
  pinned.current.icon,
  conditionsOnly.current.icon,
  "forecast supplies a day/night icon when present"
);

const auto = weather.buildView({
  location: weather.emptyLocation(),
  detectedPlaceName: "Stokesdale",
  conditions: conditions,
  forecast: forecast,
  unit: "metric",
  locale: "en_US",
  today: "2026-09-19",
});

equal(auto.current.temperature, "26", "auto-detect uses conditions for current");
equal(
  auto.current.icon,
  pinned.current.icon,
  "auto-detect still prefers a day/night icon when forecast exists"
);
equal(auto.units, "metric", "honors a metric override");
equal(auto.location.name, "Stokesdale", "uses the detected place name when none is saved");

const empty = weather.buildView({});
equal(empty.location.name, "", "starts without a location name");
equal(empty.current, null, "starts without current weather");
equal(empty.forecast, [], "starts without a forecast");

console.log("ok");
