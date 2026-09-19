function emptyLocation() {
  return { name: "", latitude: null, longitude: null }
}

function parseSavedLocation(raw) {
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return emptyLocation()

    var location = {
      name: typeof data.name === "string" ? data.name.replace(/^\s+|\s+$/g, "") : "",
      latitude: parseFloat(data.latitude),
      longitude: parseFloat(data.longitude)
    }
    if (!hasCoordinates(location)) {
      location.latitude = null
      location.longitude = null
    }
    return location
  } catch (e) {
    return emptyLocation()
  }
}

function hasCoordinates(location) {
  return !!location
    && !isNaN(parseFloat(String(location.latitude)))
    && !isNaN(parseFloat(String(location.longitude)))
}

function locationQuery(location) {
  location = location || emptyLocation()
  if (hasCoordinates(location))
    return parseFloat(String(location.latitude)) + "," + parseFloat(String(location.longitude))

  var name = String(location.name || "").replace(/^\s+|\s+$/g, "")
  return name === "" ? "" : encodeURIComponent(name)
}

function conditionsUrl(query) {
  return "https://wttr.in/" + String(query || "") + "?format=j1"
}

function detectedPlaceUrl() {
  return "https://wttr.in/?format=%l"
}

function forecastUrl(coordinates) {
  if (!coordinates) return ""
  return "https://api.open-meteo.com/v1/forecast"
    + "?latitude=" + encodeURIComponent(String(coordinates.latitude))
    + "&longitude=" + encodeURIComponent(String(coordinates.longitude))
    + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
    + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
    + "&forecast_days=4"
    + "&timezone=auto"
}

function locationSearchUrl(query) {
  return "https://geocoding-api.open-meteo.com/v1/search?name="
    + encodeURIComponent(String(query || ""))
    + "&count=5&language=en&format=json"
}

function parseDetectedPlaceName(raw) {
  var text = String(raw || "").replace(/^\s+|\s+$/g, "")
  return text === "" ? "" : text.split(",")[0]
}

function forecastCoordinates(location, conditions) {
  if (hasCoordinates(location))
    return { latitude: parseFloat(String(location.latitude)), longitude: parseFloat(String(location.longitude)) }

  var area = reportArea(conditions)
  if (!area) return null
  var lat = parseFloat(String(area.latitude || ""))
  var lon = parseFloat(String(area.longitude || ""))
  if (isNaN(lat) || isNaN(lon)) return null
  return { latitude: lat, longitude: lon }
}

function reportArea(report) {
  return report && report.nearest_area && report.nearest_area[0] ? report.nearest_area[0] : null
}

function reportAreaName(report) {
  var area = reportArea(report)
  return area && area.areaName && area.areaName[0] ? area.areaName[0].value : ""
}

function reportCountry(report) {
  var area = reportArea(report)
  return area && area.country && area.country[0] ? area.country[0].value : ""
}

function reportCurrent(report) {
  return report && report.current_condition && report.current_condition[0] ? report.current_condition[0] : null
}

function parseLocationSuggestions(raw) {
  try {
    var data = JSON.parse(String(raw || "{}"))
    var results = data.results
    if (!results || !results.length) return []

    var out = []
    for (var i = 0; i < results.length; i++) {
      var r = results[i]
      if (!r || !r.name || r.latitude === undefined || r.longitude === undefined) continue
      var region = [r.admin1, r.country].filter(function(part) { return !!part }).join(", ")
      out.push({
        name: String(r.name),
        description: region,
        latitude: r.latitude,
        longitude: r.longitude
      })
    }
    return out
  } catch (e) {
    return []
  }
}

function commitLocation(text, suggestions, selectedIndex) {
  var name = String(text || "").replace(/^\s+|\s+$/g, "")
  if (name === "") return { name: "", latitude: null, longitude: null }

  var choices = suggestions || []
  var index = Math.max(0, Math.min(parseInt(selectedIndex, 10) || 0, choices.length - 1))
  var suggestion = choices[index]
  if (suggestion) return suggestion

  return { name: name, latitude: null, longitude: null }
}

function isFutureForecastDate(dateString, todayString) {
  if (!dateString) return false
  return String(dateString).slice(0, 10) > String(todayString || "")
}

function roundedTemp(value) {
  if (value === undefined || value === null || value === "") return ""
  var n = parseFloat(String(value))
  return isNaN(n) ? "" : String(Math.round(n))
}

function celsiusToFahrenheit(value) {
  if (value === undefined || value === null || value === "") return ""
  var n = parseFloat(String(value))
  return isNaN(n) ? "" : (n * 9 / 5) + 32
}

function formatTemp(value, useImperial) {
  if (value === undefined || value === null || value === "") return ""
  return value + "°" + (useImperial ? "F" : "C")
}

function normalizedUnit(value) {
  return String(value || "").replace(/^\s+|\s+$/g, "").toLowerCase()
}

function localeUsesImperial(localeName) {
  var name = String(localeName || "").replace(".", "_")
  return /^en[_-]US($|[_.-])/.test(name) || /^en[_-]LR($|[_.-])/.test(name) || /^my($|[_.-])/.test(name)
}

function countryUsesImperial(countryName) {
  var country = String(countryName || "")
    .replace(/^\s+|\s+$/g, "")
    .replace(/[._-]+/g, " ")
    .toLowerCase()
  if (!country) return null
  if (country === "us" || country === "usa" || country === "united states" || country === "united states of america") return true
  if (country === "liberia" || country === "myanmar" || country === "burma") return true
  return false
}

function shouldUseImperial(unitOverride, localeName, countryName) {
  var unit = normalizedUnit(unitOverride)
  if (unit === "imperial") return true
  if (unit === "metric") return false

  var countryPreference = countryUsesImperial(countryName)
  if (countryPreference !== null) return countryPreference

  return localeUsesImperial(localeName)
}

function dayName(dateString, formatter) {
  if (!dateString) return ""
  var d = new Date(dateString + "T12:00:00")
  if (isNaN(d.getTime())) return ""
  if (formatter) return formatter(d)
  return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][d.getDay()]
}

function dailyForecastDays(dailyReport, todayString) {
  var daily = dailyReport && dailyReport.daily ? dailyReport.daily : null
  if (!daily || !daily.time) return []

  var result = []
  for (var i = 0; i < daily.time.length && result.length < 3; ++i) {
    var date = daily.time[i]
    if (!isFutureForecastDate(date, todayString)) continue

    var maxC = daily.temperature_2m_max ? daily.temperature_2m_max[i] : ""
    var minC = daily.temperature_2m_min ? daily.temperature_2m_min[i] : ""
    result.push({
      date: date,
      maxtempC: roundedTemp(maxC),
      mintempC: roundedTemp(minC),
      maxtempF: roundedTemp(celsiusToFahrenheit(maxC)),
      mintempF: roundedTemp(celsiusToFahrenheit(minC)),
      openMeteoWeatherCode: daily.weather_code ? daily.weather_code[i] : null
    })
  }
  return result
}

function dailyCurrentCondition(dailyReport) {
  var current = dailyReport && dailyReport.current ? dailyReport.current : null
  if (!current || current.temperature_2m === undefined || current.temperature_2m === null) return null
  return {
    temp_C: roundedTemp(current.temperature_2m),
    temp_F: roundedTemp(celsiusToFahrenheit(current.temperature_2m)),
    FeelsLikeC: roundedTemp(current.apparent_temperature),
    FeelsLikeF: roundedTemp(celsiusToFahrenheit(current.apparent_temperature)),
    windspeedKmph: roundedTemp(current.wind_speed_10m),
    windspeedMiles: roundedTemp(current.wind_speed_10m * 0.621371),
    humidity: roundedTemp(current.relative_humidity_2m),
    openMeteoWeatherCode: current.weather_code,
    isDay: current.is_day
  }
}

function currentIcon(current, fallback) {
  if (!current) return fallback || ""
  if (current.openMeteoWeatherCode !== undefined && current.openMeteoWeatherCode !== null)
    return iconForOpenMeteoCode(current.openMeteoWeatherCode, Number(current.isDay) === 0)
  if (current.weatherCode !== undefined && current.weatherCode !== null)
    return iconForCode(current.weatherCode, false)
  return fallback || ""
}

function primaryForecastDays(report, todayString) {
  var days = report && report.weather ? report.weather : []
  var result = []
  for (var i = 0; i < days.length && result.length < 3; ++i) {
    if (isFutureForecastDate(days[i].date, todayString)) result.push(days[i])
  }
  return result
}

function buildForecastDays(report, dailyReport, todayString) {
  var days = dailyForecastDays(dailyReport, todayString)
  return days.length > 0 ? days : primaryForecastDays(report, todayString)
}

function bareTempForDay(day, kind, useImperial) {
  if (!day) return ""
  var v = useImperial
    ? (kind === "max" ? day.maxtempF : day.mintempF)
    : (kind === "max" ? day.maxtempC : day.mintempC)
  if (v === undefined || v === null || v === "") return ""
  return v + "°"
}

function dayIcon(day) {
  if (!day) return ""
  if (day.openMeteoWeatherCode !== undefined && day.openMeteoWeatherCode !== null)
    return iconForOpenMeteoCode(day.openMeteoWeatherCode)
  if (!day.hourly || day.hourly.length === 0) return ""

  var best = day.hourly[0]
  var bestDist = 9999
  for (var i = 0; i < day.hourly.length; ++i) {
    var t = parseInt(String(day.hourly[i].time || "0"), 10)
    var dist = Math.abs(t - 1200)
    if (dist < bestDist) {
      bestDist = dist
      best = day.hourly[i]
    }
  }
  return iconForCode(best.weatherCode, false)
}

function missingMoonEvent(value) {
  var text = String(value || "").replace(/^\s+|\s+$/g, "")
  if (text === "") return true
  return /^no moon(rise|set)$/i.test(text)
}

function reportAstronomy(report, today) {
  var days = report && report.weather ? report.weather : []
  for (var i = 0; i < days.length; i++) {
    var day = days[i]
    if (day && day.date === today)
      return day.astronomy && day.astronomy[0] ? day.astronomy[0] : null
  }
  return null
}

function buildSun(astro) {
  return {
    sunrise: astro && astro.sunrise ? String(astro.sunrise) : "",
    sunset: astro && astro.sunset ? String(astro.sunset) : ""
  }
}

function buildMoon(astro) {
  if (!astro) return { phase: "", illumination: "", rise: null, set: null }
  return {
    phase: astro.moon_phase ? String(astro.moon_phase) : "",
    illumination: astro.moon_illumination ? String(astro.moon_illumination) + "%" : "",
    rise: missingMoonEvent(astro.moonrise) ? null : String(astro.moonrise),
    set: missingMoonEvent(astro.moonset) ? null : String(astro.moonset)
  }
}

function pickCurrent(hasCoords, dailyCurrent, primaryCurrent) {
  if (hasCoords && dailyCurrent) return dailyCurrent
  return primaryCurrent || dailyCurrent
}

function formatForecast(days, useImperial, formatDayName) {
  var out = []
  for (var i = 0; i < days.length; i++) {
    var day = days[i]
    out.push({
      date: day.date,
      weekday: String(dayName(day.date, formatDayName) || "").toUpperCase(),
      icon: dayIcon(day),
      high: bareTempForDay(day, "max", useImperial),
      low: bareTempForDay(day, "min", useImperial)
    })
  }
  return out
}

function displayLocationName(location, detectedPlaceName, conditions) {
  if (location.name) return location.name
  if (detectedPlaceName) return detectedPlaceName
  return reportAreaName(conditions)
}

function buildView(input) {
  input = input || {}
  var location = input.location || emptyLocation()
  var conditions = input.conditions
  var forecastDoc = input.forecast
  var outlookCurrent = dailyCurrentCondition(forecastDoc)
  var conditionsCurrent = reportCurrent(conditions)
  var currentRaw = pickCurrent(hasCoordinates(location), outlookCurrent, conditionsCurrent)
  var country = reportCountry(conditions)
  var useImperial = shouldUseImperial(input.unit, input.locale, country)
  var forecast = formatForecast(
    buildForecastDays(conditions, forecastDoc, input.today),
    useImperial,
    input.formatWeekday
  )
  var astronomy = reportAstronomy(conditions, input.today)
  var current = null
  if (currentRaw) {
    current = {
      icon: currentIcon(outlookCurrent, "") || currentIcon(currentRaw, ""),
      temperature: String(useImperial ? currentRaw.temp_F : currentRaw.temp_C),
      unit: useImperial ? "°F" : "°C",
      feelsLike: formatTemp(useImperial ? currentRaw.FeelsLikeF : currentRaw.FeelsLikeC, useImperial),
      wind: useImperial
        ? (currentRaw.windspeedMiles + " mph")
        : (currentRaw.windspeedKmph + " km/h"),
      humidity: currentRaw.humidity + "%"
    }
  }

  return {
    location: {
      name: displayLocationName(location, input.detectedPlaceName, conditions),
      country: country
    },
    units: useImperial ? "imperial" : "metric",
    current: current,
    sun: buildSun(astronomy),
    moon: buildMoon(astronomy),
    forecast: forecast
  }
}

function iconForOpenMeteoCode(code, night) {
  var c = parseInt(String(code || "0"), 10)
  if (c === 0) return iconForCode(113, night)
  if (c === 1 || c === 2) return iconForCode(116, night)
  if (c === 3) return iconForCode(119, night)
  if (c === 45 || c === 48) return iconForCode(143, night)
  if (c === 51 || c === 53 || c === 55 || c === 56 || c === 57 || c === 61) return iconForCode(266, night)
  if (c === 63 || c === 65 || c === 66 || c === 67 || c === 80 || c === 81 || c === 82) return iconForCode(308, night)
  if (c === 71 || c === 73 || c === 75 || c === 77 || c === 85 || c === 86) return iconForCode(338, night)
  if (c === 95 || c === 96 || c === 99) return iconForCode(389, night)
  return iconForCode(119, night)
}

function iconForCode(code, night) {
  var c = parseInt(String(code || "0"), 10)
  switch (c) {
    case 113: return night ? "" : ""
    case 116: return night ? "" : ""
    case 119: case 122: return ""
    case 143: case 248: case 260: return night ? "\ue346" : "\ue313"
    case 176: case 263: case 353: return night ? "" : ""
    case 179: case 227: case 230: case 323: case 326: case 368: return night ? "" : ""
    case 182: case 185: case 281: case 284: case 311: case 314:
    case 317: case 320: case 350: case 362: case 365: case 374: case 377: return ""
    case 200: case 386: case 389: case 392: case 395: return ""
    case 266: case 293: case 296: case 299: case 302: case 305: case 308: case 356: case 359: return ""
    case 329: case 332: case 335: case 338: case 371: return ""
    default: return ""
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    emptyLocation: emptyLocation,
    parseSavedLocation: parseSavedLocation,
    hasCoordinates: hasCoordinates,
    locationQuery: locationQuery,
    conditionsUrl: conditionsUrl,
    forecastUrl: forecastUrl,
    detectedPlaceUrl: detectedPlaceUrl,
    locationSearchUrl: locationSearchUrl,
    parseDetectedPlaceName: parseDetectedPlaceName,
    forecastCoordinates: forecastCoordinates,
    parseLocationSuggestions: parseLocationSuggestions,
    commitLocation: commitLocation,
    buildView: buildView
  }
}
