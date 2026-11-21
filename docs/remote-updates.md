# Remote updates (1.0.3)

How HandStrudel changes behaviour and content without a new App Store build, and where that stops.

## The idea

The app ships with everything it needs. The server can only **choose between behaviours the shipped code already has** and **send data that shipped code renders**. Three pieces do that:

| Piece | Server side | App side |
|---|---|---|
| Remote config and flags | `public.app_config` rows, read through `app_config_for()` | `RemoteConfig` (`ios/.../Models/RemoteConfig.swift`) |
| Update prompt | `update.*` keys in the same table | `RemoteUpdateGate` banner and blocker |
| Downloadable instruments | `public.instrument_catalog` rows, read through `instrument_catalog_for()` | `InstrumentCatalog` (`ios/.../Models/InstrumentCatalog.swift`) |

The key list, types and defaults live in `shared/remote-config/keys.json`, and the cross-platform rules (version comparison, rollout buckets, resolution) are pinned by `shared/remote-config/fixtures/`. The iOS unit tests and pgTAP tests both check them, and the web app's TypeScript port must pass the same files.

## Remote config and flags

### Data model

`public.app_config` has one row per *variant* of a key:

| Column | Meaning |
|---|---|
| `key` | Dotted name, e.g. `feed.enabled`. Must be in `keys.json` to have any effect; apps ignore unknown keys. |
| `value` | JSON. Apps ignore a value whose type doesn't match the key's type and keep the built-in default. |
| `platform` | `all`, `ios`, `android` or `web`. |
| `min_app_version`, `max_app_version` | Inclusive bounds, `major.minor.patch` (missing parts are 0). Null means unbounded. |
| `rollout_percent` | 0–100. An install is in when its bucket for this key is below the percentage. |
| `priority` | Higher wins when several rows match. Ties go to the newest row. |
| `enabled` | Set false to switch a row off without deleting it. |
| `note` | Free text for admins: why the row exists, who to ask. |

RLS is on and there are no client policies: anon and signed-in users can't read or write the table. They call `app_config_for(platform, app_version)`, a `security definer` function that returns the enabled rows for that platform and version, without notes. Only the service role (the dashboard, the admin script) writes.

### Resolution

For each key the app takes the matching rows in order (priority, then newest) and uses the first whose rollout admits this install. If none does, it uses the built-in default. So a 10% rollout of `true` over a default of `false` is one row, and "everyone on 1.0.2 sees X, 10% of 1.0.3 sees Y" is two rows.

**Rollout bucket.** `bucket = uint32(first 4 bytes of SHA-256("<key>:<install_id>")) mod 100`. Salting by key means the same 10% of people aren't first for every flag. Raising the percentage only adds installs; nobody who had the feature loses it.

**Install id.** A random UUID created on first launch and kept in `UserDefaults`. It never leaves the device: the server filters by platform and version, and the app applies the rollout itself. It isn't the IDFA or IDFV, isn't tied to an account, and resets on reinstall, so it is not a tracking identifier and needs no ATT prompt or privacy-label change. `app_config_resolve(platform, version, install_id)` exists only for admins to preview what a given install would see.

### App behaviour

- Built-in defaults equal today's behaviour, so first launch, offline use and a dead backend all behave like 1.0.2.
- At launch the app reads the last good copy from Application Support (a few KB), then fetches in the background. It never waits for the network to show UI.
- It fetches again on foreground, at most every 15 minutes. A failed fetch keeps the cached copy.
- A successful fetch replaces the whole snapshot, so a deleted or disabled row falls back to the default on the next fetch.
- The cache is dropped when the app version changes, because the server filtered it for the old version.
- DEBUG builds can serve a local fixture instead of the network: set `HANDSTRUDEL_REMOTE_CONFIG_FIXTURE` (and `HANDSTRUDEL_INSTRUMENT_CATALOG_FIXTURE`) to a file path or inline JSON in the RPC's row format.

### Keys in 1.0.3

| Key | Type | Default | What it does |
|---|---|---|---|
| `feed.enabled` | bool | `true` | Kill switch. False replaces the feed tab with a short "taking a break" note; music, drafts and the account tab keep working. Takes effect on the next fetch. On a launch with no cached config (first launch, or the first after an app update) the feed can send its first request before the fetch returns; once cached, the switch applies from launch. |
| `feed.page_size` | number | `10` | Posts per page for the Latest and Following feeds and profile and play-along lists (Discover always loads 24), clamped to 5–30. Read once per launch from the cached copy, so it applies from the launch after the fetch. |
| `store.pro_title` | string | `HandStrudel Pro` | Store screen headline for Pro. |
| `store.pro_features` | string array | today's 4 lines | Pro feature bullets (up to 6, 80 characters each). |
| `store.pro_note` | string | empty | Optional line under the bullets, e.g. a sale. Hidden when empty. |
| `update.minimum_version` | string | none | Versions below this see a full-screen "Update required" screen. |
| `update.recommended_version` | string | none | Versions below this see a dismissible "Update available" banner (outside a performance). |
| `update.message` | string | empty | Optional text for the banner and the blocker. |
| `update.app_store_url` | string | the App Store page | Where the Update buttons go. Must be an `https://apps.apple.com/` link or it's ignored. |
| `instruments.remote_enabled` | bool | `true` | False hides downloaded instruments and stops catalog fetches. |

Prices always come from StoreKit. Config changes only the words around a price, never the price or what a product unlocks.

## Update prompt

`update.recommended_version` shows a banner that the player can dismiss; it comes back when the recommended version goes up. `update.minimum_version` blocks the app with an App Store button. Use it only for builds that are broken or unsafe (a data-corrupting bug, an API the backend has dropped), and only after the fixed build is live in the App Store in every territory: a minimum version that isn't downloadable yet locks people out.

## Downloadable instruments

`public.instrument_catalog` holds published instrument files (the format in `shared/instruments/`): `id`, `format_version`, the file itself in `body` (16 KB max, the same limit the loader enforces), `platform`, `min_app_version`, `published` and `sort_order`. The table checks that `body.id` and `body.format_version` match the columns and that ids don't use the reserved `builtin.` prefix. Apps read it through `instrument_catalog_for(platform, app_version, max_format_version)`, which leaves out unpublished rows and formats newer than the app reads.

The app then:

1. Skips any row whose `format_version` is newer than `InstrumentSpec.formatVersion` (in case the server didn't filter).
2. Runs every body through `InstrumentSpec.load`, exactly like a bundled file: rejected files are dropped, out-of-range values repaired.
3. Drops files whose id is `builtin.*`, whose loaded id doesn't match the row, or that collide with a bundled instrument. **Bundled files win.**
4. Caches the accepted bodies in Application Support and re-validates them from the cache on the next launch.
5. Merges them after the bundled library (`InstrumentCatalog.all`).

The 1.0.3 prototype shows the merged list in the DEBUG instrument picker in the control sheet.

### Why this complies with App Store Review Guideline 2.5.2

2.5.2 says an app may not "download, install, or execute code which introduces or changes features or functionality of the app". Everything this design downloads is data:

- **Config values** are JSON scalars, strings and lists that pick between code paths already in the reviewed binary (show the feed or not, which text to show). There is no scripting, no expression language and no URL-to-code mapping.
- **Instrument files** are declarative JSON checked against a closed vocabulary (`split_wheel`, `left`/`right`, `scale_one_octave`, ...) and numeric ranges. The shipped renderer draws them; a file can't add a surface type, a gesture or a sound the binary doesn't have. Unknown fields are ignored, never interpreted. New surface types need a new `format_version`, which ships in an app update.
- **Nothing is executed.** No JavaScript reaches the Strudel WebView from config or catalogs, no `NSExpression`/`JSContext`/dynamic library loading, and instruments never contain Strudel code, sound names, keys or scales (see `shared/instruments/README.md`).
- Every new behaviour still goes through review before any flag can turn it on, so a flag can't reveal hidden features to bypass review (Guideline 2.3.1): flagged features are present and reachable in the reviewed build or harmless when off. Ship flagged code switched **on** by default for review, or tell App Review how to see it.

## What changes without a release

- Feature flags and kill switches for code that's already in the build.
- Numeric tunables and copy (store text, banners).
- Gradual rollouts and rollbacks by version, platform and percentage.
- New instruments in the current format.
- Update prompts and forced updates.

## What still needs a release

- Any new native code, UI or behaviour, including new instrument surface types or `format_version` bumps.
- New permissions or `Info.plist` usage strings, entitlements, capabilities or privacy-manifest changes.
- New in-app purchase products or types, or changes to what a purchase unlocks.
- New config keys: an app only reads the keys it was built with.
- Changes to the app's Strudel engine bundle or SoundFonts.

## Rolling out and rolling back a flag

1. Ship the code behind a key with a default equal to the safe, current behaviour.
2. Add a row with `rollout_percent = 5` (and `min_app_version` set to the first build that has the code).
3. Watch crash reports, support mail and usage analytics; raise to 25, 50, 100.
4. When it's at 100% for everyone who matters, make the new value the built-in default in a later release and delete the row.

**Roll back** by setting `enabled = false` on the row (or `rollout_percent = 0`). Installs pick that up on their next fetch: at launch, or on foreground once 15 minutes have passed since the last fetch. There is no push; plan for most active users within the hour.

## Admin how-to

Everything below runs against a Supabase project with its service-role key. Use the local stack to try changes first. **Production writes are deliberate:** the script refuses a non-local URL unless you pass `--prod`.

```bash
export SUPABASE_URL=http://127.0.0.1:54321          # or the production URL with --prod
export SUPABASE_SERVICE_ROLE_KEY=...                 # never commit it
```

The script is `scripts/remote-config.mjs` (Node 20, no dependencies):

```bash
node scripts/remote-config.mjs list
node scripts/remote-config.mjs set feed.enabled false --note "feed incident 2026-12-01"
node scripts/remote-config.mjs set store.pro_note '"Holiday sale"' --platform ios
node scripts/remote-config.mjs set feed.page_size 15 --rollout 10 --min 1.0.3
node scripts/remote-config.mjs set update.recommended_version '"1.0.3"'
node scripts/remote-config.mjs disable 42          # row id from `list`
node scripts/remote-config.mjs delete 42
node scripts/remote-config.mjs preview --version 1.0.3 --install 2f6c…   # what that install resolves to
node scripts/remote-config.mjs publish-instrument path/to/instrument.json [--min 1.0.3] [--order 10]
node scripts/remote-config.mjs unpublish-instrument community.big-wheel
```

`set` checks the key and value type against `keys.json` before writing. `publish-instrument` checks the file's format, version, id and size; the app re-validates every file anyway.

The same in SQL (dashboard SQL editor, as the service role):

```sql
-- Kill the feed for everyone
insert into public.app_config (key, value, note) values ('feed.enabled', 'false', 'feed incident');
-- Roll it back
update public.app_config set enabled = false where key = 'feed.enabled';

-- Force 1.0.1 and older to update, once 1.0.3 is live everywhere
insert into public.app_config (key, value, platform, note)
values ('update.minimum_version', '"1.0.2"', 'ios', '1.0.1 can''t post after the upload change');

-- Publish an instrument
insert into public.instrument_catalog (id, format_version, body)
values ('community.big-wheel', 1, '{ ...the file... }'::jsonb);
update public.instrument_catalog set published = false where id = 'community.big-wheel';
```

## Testing

- `supabase test db` runs `supabase/tests/database/remote_config.test.sql`: RLS (clients can't read or write the tables, the preview is admin-only), platform and version targeting, priority, rollout, the shared bucket and version fixtures, and the catalog's checks.
- iOS unit tests: `RemoteConfigTests` (shared fixtures, defaults, cache, throttling, update prompt) and `InstrumentCatalogTests` (validation, future formats, malformed files, bundled-wins merge, cache).
- `RemoteConfigUITests` launch the app with `HANDSTRUDEL_REMOTE_CONFIG_FIXTURE` / `HANDSTRUDEL_INSTRUMENT_CATALOG_FIXTURE` set to inline rows and drive it: the feed kill switch, the banner (tap Update, dismiss, relaunch), the hard block (taps don't reach the app; Update leaves it), the store copy in the Store sheet, and playing a downloaded instrument (the wheel's chord half moves sides) while bad, future-format and colliding files stay out of the picker. `--reset-remote-content` (DEBUG) clears the cache first.
- `RemoteConfigLiveUITests` (opt-in) go through the app's real network code against a local stack: they write rows with the service key, check the app picks them up from `app_config_for()` / `instrument_catalog_for()` (including platform and version targeting), roll back (disable the row, unpublish the instrument) and check the app follows. Run with `TEST_RUNNER_HANDSTRUDEL_LIVE_SUPABASE_URL`, `TEST_RUNNER_HANDSTRUDEL_LIVE_ANON_KEY` and `TEST_RUNNER_HANDSTRUDEL_LIVE_SERVICE_KEY` set (local URLs only); the stack's Kong log shows the Latest feed's `limit=` equal to `feed.page_size`.
- The Simulator has no App Store app, so `apps.apple.com` links land in Safari, which can't show them there; check the App Store page opening on a device.
