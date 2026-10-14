# World environment time audit — 23 September 2026

This is a read-only audit of `world.html`, `Mafiozi3DBridge` and the current
Three renderer consumer. No world, walk or renderer host was changed.

## Authority and cadence

The only clock authority is the page-local lexical `_gameMinutes` in
`world.html`. It starts at `12 * 60`. `updateGameClock` runs immediately and
then through `setInterval(..., 1000)`. Each callback advances exactly one game
minute, so the intended rate is one real second per game minute. It is tick
count based: delayed or throttled callbacks do not compensate from wall time.

The first immediate callback writes `12:00` to the 2D HUD and then advances the
internal value to `12:01`. Every later callback has the same ordering. Thus a
bridge read after the callback is normally one game minute ahead of the 2D HUD
text. The bridge itself does not mutate time.

There is no clock load/save, local/session storage key, API receipt, WebSocket
update, or server clock assignment. A page reload starts a new local clock at
noon. Names such as `serverTime`, `lastServerHour` and the UI title “server city
time” in `three_preview.js` do not establish server synchronization.

The Three renderer takes one initial environment snapshot, then checks the
bridge from its frame loop when `t >= timeSampleAt` and advances the deadline to
`t + 250`. This is a target four-Hz cadence with no catch-up burst. Actual reads
are at least 250 ms apart and can be later by one frame or by background-tab
throttling; the code does not guarantee a maximum sample age of 250 ms. The safe
consumer pattern is one read per frame at most, with a 250 ms target deadline,
retaining the last valid sample if a frame or bridge read is missed.

`previewtimeoffset` affects only URLs that also contain `preview`; production
uses zero offset.

## `getEnvironmentState` snapshot

Before returning, finite `_gameMinutes` wraps into `[0, 1440)`. Non-finite
source time falls back to `720` (12:00). The synchronous snapshot contains:

- `hour`: integer from 0 through 23.
- `minute`: integer from 0 through 59.
- `districtId`: result of `districtStyleIdAt(player.r, player.c)`, or `null` if
  that function is unavailable. The return itself is not normalized.
- `mapRows`, `mapCols`, `blockSize`, `beachRow`, `waterRow`: current world
  geometry scalars.
- `traffic.ew`, `traffic.ns`: current 16-second `performance.now()` traffic
  phase. Its expected symbols are `g`, `y`, and `r`. If `trafficPhase` is not a
  function, the bridge fallback is `{ew:'g', ns:'r'}`.

It does not return seconds, epoch, day index, clock revision, weather,
daylight, dawn/dusk, lamp state, or persistence/server provenance.

## Light boundaries

The 2D world tint and Three lighting intentionally use different curves:

- The 2D night alpha is deep night from 00:00–05:00, fades from 0.55 to zero
  during 05:00–07:00, is clear from 07:00–17:00, rises to 0.30 during
  17:00–19:00, rises to 0.50 during 19:00–22:00, and reaches 0.55 by 24:00.
- Three dawn influence is nonzero inside 04:30–08:12, with its full plateau at
  06:12–06:30. Three dusk influence is nonzero inside 16:36–20:42, with its
  full plateau at 18:30–18:48. The palette eases toward targets at rate 2.4/s,
  with palette delta capped at 0.1 s, so displayed phase boundaries lag the
  sampled clock rather than snapping.
- Three daylight is a smooth sine-derived curve. It is zero until about 05:14,
  fully reaches day around 07:34, starts leaving full day around 16:26, and
  reaches zero around 18:46.
- Street lamps use a discrete authored schedule independent of the sky curve:
  on at 17:00 inclusive, remain on through 06:59, and off at 07:00 inclusive
  through 16:59. While scheduled on, power is `max(0.48, night)`; otherwise it
  is zero. Electrical flicker and visibility budgets are applied per frame.

## Invalid values and fallback contract

For future consumers, a clock sample should be valid only when it is an object
whose `hour` and `minute` are finite integer **numbers**, with hour in `0..23`
and minute in `0..59`. Missing objects/fields, `null`, booleans, numeric strings,
fractions, `NaN`, infinities, negative values, hour 24+, and minute 60+ are
invalid. At startup use 12:00 if there is no valid snapshot; after startup keep
the last valid sample. Never replace an invalid sample with animation uptime,
and never reinterpret it as midnight.

The current Three consumer is looser: `Number.isFinite(+value)` accepts `null`,
booleans, numeric strings and out-of-range finite values. This audit records the
gap; it does not modify the host.

Expected traffic values are exactly `g`, `y`, or `r` for both axes. A missing,
non-object, or unknown traffic value should retain the last valid phase; the
startup fallback is east-west green/north-south red. Geometry fields should be
finite, with `mapRows`, `mapCols`, and `blockSize` positive and beach/water rows
within map bounds. Invalid optional `districtId` should normalize to `null`.

The read-only contract test is
`outputs/test_world_environment_time_contract23.mjs`. It pins the source
authority, write count, snapshot fields, cadence, QA-offset guard, current
validation gap, dawn/dusk/lamp boundaries, and the absence of another direct
clock assignment.
