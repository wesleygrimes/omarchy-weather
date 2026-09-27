function validCoordinates(point) {
  if (!point || point.latitude === null || point.longitude === null) return false;
  if (String(point.latitude).trim() === "" || String(point.longitude).trim() === "") return false;
  var latitude = Number(point.latitude);
  var longitude = Number(point.longitude);
  return (
    isFinite(latitude) &&
    isFinite(longitude) &&
    latitude >= -85.0511 &&
    latitude <= 85.0511 &&
    longitude >= -180 &&
    longitude <= 180
  );
}

function coordinateText(value) {
  var text = String(Number(value));
  return text.indexOf(".") >= 0 ? text : text + ".0";
}

function locationKey(point) {
  if (!validCoordinates(point)) return "";
  return coordinateText(point.latitude) + "," + coordinateText(point.longitude);
}

function parseManifest(raw, point, now) {
  if (!validCoordinates(point)) return [];
  var manifest = typeof raw === "string" ? JSON.parse(raw) : raw;
  if (!manifest || typeof manifest !== "object") throw new Error("Invalid radar manifest");
  var host = String(manifest.host || "");
  var match = /^https:\/\/([a-z0-9.-]+)(?:\/)?$/i.exec(host);
  if (!match || !/(^|\.)rainviewer\.com$/i.test(match[1])) throw new Error("Invalid radar host");
  var past = manifest.radar && manifest.radar.past;
  if (!Array.isArray(past)) throw new Error("Missing radar history");
  var byTime = {};
  var present = Number(now) || Math.floor(Date.now() / 1000);
  for (var i = 0; i < past.length; i++) {
    var entry = past[i];
    if (!entry || !Number.isInteger(entry.time) || entry.time <= 0 || entry.time > present + 120)
      continue;
    if (typeof entry.path !== "string" || !/^\/v2\/radar\/[A-Za-z0-9_-]+$/.test(entry.path))
      continue;
    byTime[entry.time] = entry.path;
  }
  var times = Object.keys(byTime)
    .map(Number)
    .sort(function (a, b) {
      return a - b;
    });
  if (times.length === 0) return [];
  var newest = times[times.length - 1];
  var result = [];
  for (var j = 0; j < times.length; j++) {
    var time = times[j];
    if (time < newest - 3600) continue;
    result.push({
      time: time,
      url:
        host.replace(/\/$/, "") +
        byTime[time] +
        "/512/7/" +
        coordinateText(point.latitude) +
        "/" +
        coordinateText(point.longitude) +
        "/2/1_1.png",
    });
  }
  if (result.length <= 7) return result;
  var sampled = [];
  for (var index = 0; index < 7; index++)
    sampled.push(result[Math.round((index * (result.length - 1)) / 6)]);
  return sampled;
}

if (typeof module !== "undefined")
  module.exports = {
    validCoordinates: validCoordinates,
    locationKey: locationKey,
    parseManifest: parseManifest,
  };
