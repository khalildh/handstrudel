# Remote config

Keys HandStrudel apps read from `public.app_config`, and the rules every implementation follows. See `docs/remote-updates.md` for the design and admin steps.

- `keys.json`: every key with its type, default and limits. Defaults equal the app's behaviour without config. An app only reads keys it was built with.
- `fixtures/versions.json`: app version parsing and comparison.
- `fixtures/buckets.json`: rollout buckets (`SHA-256("<key>:<install_id>")`, first 4 bytes, mod 100). pgTAP checks the same numbers.
- `fixtures/resolve.json`: per-key resolution from the rows `app_config_for()` returns.

iOS: `RemoteConfigTests`. Web (later): port `RemoteConfig.swift` and pass the same files.
