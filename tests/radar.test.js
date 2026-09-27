const assert = require("assert");
const radar = require("../Radar.js");

assert.strictEqual(radar.validCoordinates({ latitude: "", longitude: 0 }), false);
assert.strictEqual(radar.validCoordinates({ latitude: 90, longitude: 0 }), false);
assert.strictEqual(radar.validCoordinates({ latitude: 34.0259, longitude: -118.7798 }), true);
assert.strictEqual(radar.locationKey({ latitude: 0, longitude: -120 }), "0.0,-120.0");

const newest = 1780000000;
const past = [];
for (let offset = -3600; offset <= 0; offset += 450)
  past.push({ time: newest + offset, path: `/v2/radar/frame${offset + 3600}` });
past.push({ time: newest, path: "/v2/radar/newest" });
past.push({ time: newest + 900, path: "/v2/radar/future" });
past.push({ time: newest - 3900, path: "/v2/radar/too-old" });
past.push({ time: newest - 100, path: "/v2/radar/../../bad" });

const frames = radar.parseManifest(
  { host: "https://tilecache.rainviewer.com", radar: { past } },
  { latitude: 34.0259, longitude: -118.7798 },
  newest
);
assert.strictEqual(frames.length, 7, "bounds even unusually dense histories");
assert.strictEqual(frames[0].time, newest - 3600, "dense history still spans the last hour");
assert.strictEqual(frames.at(-1).time, newest, "newest wins duplicate timestamps");
assert.strictEqual(
  frames.at(-1).url,
  "https://tilecache.rainviewer.com/v2/radar/newest/512/7/34.0259/-118.7798/2/1_1.png"
);
assert.throws(() =>
  radar.parseManifest(
    { host: "https://evil.example", radar: { past } },
    { latitude: 0, longitude: 0 },
    newest
  )
);
assert.deepStrictEqual(
  radar.parseManifest(
    { host: "https://tilecache.rainviewer.com", radar: { past: [] } },
    { latitude: 0, longitude: 0 },
    newest
  ),
  []
);
console.log("ok");
