# TunnelCore client integration

The client uses `https://tlsdmd.isgood.host/api/vpn/v1/`, not the Django
administration at `/admin/` or the internal `/api/bot/` API.

Contract verified against `VnextDevelopment/tunnelcore`, main commit
`f97cc9b`, including device API PR #17 head `99b1737`:

- `POST auth/login/`: JSON `username`, `password` (bot credentials), or
  `email`, `password` (email login); response `ok`,
  `access_token`, `token_type: Bearer`, `expires_in`, `user`.
- `POST auth/code/exchange/`: JSON `code` (six-digit one-time code from the
  Telegram bot); response uses the same access-token contract as login.
- `POST auth/register/`: JSON `email`, `password`; creates an email account and
  returns the same access-token contract with HTTP 201.
- `POST auth/telegram/link/`: Bearer token plus JSON `code`; links a Telegram
  profile to an email account and migrates its subscriptions and payments.
- `GET me/`: Bearer token; response `user`, `subscriptions`.
- `POST devices/register/`: Bearer token plus a stable application-generated
  UUID in `device_id` and the client `platform`. Registration is idempotent for
  the same account and device; `device_limit_reached` (409) means the tariff's
  device allowance is exhausted.
- `GET configs/?device_id=<uuid>`: Bearer token; response contains safe configuration metadata
  (`id`, `name`, `location`, `protocol`, `expires_at`) without a private URL.
- `GET configs/<id>/?device_id=<uuid>`: Bearer token; consumes the application-specific one-time
  copy and returns `id`, `name`, `filename`, `protocol`, `config`, and an optional
  `obfuscation` policy. The client passes `filename` into the import flow and
  uses its safe basename (without `.conf`) as the imported AWG/WireGuard
  connection name. For `obfuscation.mode=client_dynamic`, the policy is stored
  on the managed TunnelCore profile and a fresh coherent `I1-I5` set is
  generated locally each time a new AWG connection is prepared. All five
  packets use one selected profile/source; `static` keeps the values from the
  downloaded configuration unchanged.

Legacy HTTPS configuration URLs are fetched without the account Authorization header.
Redirects are rejected; TLS verification stays enabled. Configuration contents
go through the existing import preview and parser. A 401 on an authenticated
request clears the unusable local account session without attempting another
authenticated request. Explicit logout first calls `POST devices/revoke/` for
the current `device_id`; only after the server has released the device slot and
revoked its VPN peer does the client clear the local account session. A
`device_not_found` response is treated as already released. Other revoke
failures keep the session so the user can retry instead of silently leaking a
device slot. Previously imported VPN configurations remain available.

The access token, display name, account type and successful Telegram-link state
are persisted through the application's encrypted `SecureQSettings` storage.
On startup the client validates the restored session by refreshing account data.
A rejected token is removed automatically. Login codes and passwords are never
persisted.

The generated device UUID is stored separately from the account session and is
not removed on logout. After every new or restored login the client registers
that UUID before requesting account configuration data. The same `device_id` is
sent when reading or changing the VPN country and when listing or downloading a
configuration, so the server can enforce tariff device limits and isolate each
device's peer.

## Email login

The Email tab supports both registration and sign-in. It sends only `email` and
`password`; the address is trimmed and lowercased, while the password is
preserved exactly. Registration signs the user in immediately after the server
returns the token. Switching tabs or switching between registration and sign-in
clears entered passwords and the previous error.

The server returns `email_and_password_required` (400) for invalid or missing
email/password and `invalid_credentials` (401) for rejected credentials.
Registration additionally returns `password_invalid` (400),
`email_already_registered` (409), or `registration_conflict` (409). The client
maps these failures to localized messages without opening an account. Do not
substitute Django administrator credentials or bot service tokens for end-user
authentication.

## Telegram linking

An authenticated email account can enter a six-digit PIN obtained from the
TunnelCore Telegram bot. The client sends it to `auth/telegram/link/` with the
account Bearer token. The server consumes the PIN, links the Telegram identity,
and transfers subscriptions and payments to the email account. The client then
refreshes subscriptions and configurations.

Expected failures are `invalid_or_expired_code` (401), `unauthorized` (401),
`email_account_required` (403), `telegram_link_not_found` (409), and
`telegram_account_already_linked` (409). An invalid or expired PIN does not end
the current email session; an explicit `unauthorized` response does.

## Validation

Standalone controller tests (no production credentials or network required):

```sh
cmake -S client/tests/tunnelcore -B /tmp/tunnelcore-controller-build -DCMAKE_PREFIX_PATH=/path/to/qt
cmake --build /tmp/tunnelcore-controller-build
ctest --test-dir /tmp/tunnelcore-controller-build --output-on-failure
```

Android device validation is still required for keyboard layout, VPN import and
connection with an actual account. Legacy page files remain available for
existing server management flows; the initial screen and service entry point
now lead to the TunnelCore account.
