# TunnelCore client integration

The client uses `https://tlsdmd.isgood.host/api/vpn/v1/`, not the Django
administration at `/admin/` or the internal `/api/bot/` API.

Contract verified against `VnextDevelopment/tunnelcore`, main commit
`9cd06ce`:

- `POST auth/login/`: JSON `username`, `password` (bot credentials), or
  `email`, `password` (email login); response `ok`,
  `access_token`, `token_type: Bearer`, `expires_in`, `user`.
- `POST auth/code/exchange/`: JSON `code` (six-digit one-time code from the
  Telegram bot); response uses the same access-token contract as login.
- `GET me/`: Bearer token; response `user`, `subscriptions`.
- `GET configs/`: Bearer token; response contains safe configuration metadata
  (`id`, `name`, `location`, `protocol`, `expires_at`) without a private URL.
- `GET configs/<id>/`: Bearer token; consumes the application-specific one-time
  copy and returns `id`, `protocol`, `config`.

Legacy HTTPS configuration URLs are fetched without the account Authorization header.
Redirects are rejected; TLS verification stays enabled. Configuration contents
go through the existing import preview and parser. A 401 on an authenticated
request clears the account session. Logout cancels outstanding requests and
clears the profile; previously imported VPN configurations remain available.

The access token and username are persisted through the application's encrypted
`SecureQSettings` storage. On startup the client validates the restored session
by refreshing account data. A rejected token is removed automatically. Login
codes and passwords are never persisted.

## Email login

Email login is implemented against `feature/vpn-email-auth`,
`web/vpn_api/auth_views.py` blob `00a77b91a77b6b4bf042e0ce8948fbbfbb96e592`.
The Email tab sends only `email` and `password` to `auth/login/`; the address is
trimmed and lowercased, while the password is preserved exactly. The server
validates email syntax and checks the linked enabled VPN client credential.
The response uses the same Bearer token contract as bot-credential login.
Switching tabs clears the entered credentials and previous error.

The server returns `email_and_password_required` (400) for invalid or missing
email/password and `invalid_credentials` (401) for rejected credentials.
The client displays these failures without opening the account. On 2026-09-17,
the configured live server returned `email_and_password_required` (400) for an
empty email/password request, confirming that it recognizes the email contract.
Successful sign-in with a real account has not been verified.
The branch also provides `auth/register/`, but this client change covers login
only. Do not substitute Django administrator credentials or bot service tokens
for end-user authentication.

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
