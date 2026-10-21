# TunnelCore mobile UI redesign (October 2026)

The generated iPhone mockups are **visual references, not UI assets**. Their pixels,
sample prices, countries, trial counters, number of devices and payment options
must never replace real application state or backend responses.

## Implemented QML surfaces

- Light blue/cyan design tokens, reusable labeled tab control and a circular
  connection control that reflects the real `ConnectionController` status.
- TunnelCore account: updated email/PIN sign-in, email registration, input
  styling and keyboard avoidance; the existing authorization APIs are preserved.
- Authenticated dashboard: connection status, currently selected location,
  subscription state, selectable/searchable countries and split-tunneling entry.
- Settings menu: light navigation cards.
- API country selector: selectable cards with flags and the existing
  active-connection safety checks.
- API device selector: light cards retaining the existing unlink confirmation.
- Native five-destination mobile navigation, backed by real views: VPN,
  available countries, active subscriptions, account and application settings.
- A welcome/onboarding card directs guests into actual email registration,
  email sign-in or Telegram-bot-code sign-in.
- Password visibility actions and country search preserve keyboard scrolling.

## Important product distinctions

- `Web Proxy` and `MTProto` in the reference mockups refer to separate proxy
  functionality, not existing interchangeable VPN modes. Only real connection
  protocols supplied by the app/backend should appear as VPN modes.
- Country names and subscriptions come from `TunnelCoreController` and the
  gateway API. No illustrative countries, synthetic latency or sample tariffs
  have been hard-coded into live screens.
- No fictitious five-device plan, seven-day trial, card payment, or RUB price is
  introduced. Payment entry points continue following the platform/store rules.
- Per-application routing on iOS is not implemented based on an illustration:
  split tunneling remains platform-specific as supported by the actual client.
- The mockup's checkout remains a real subscription-state/renewal screen:
  tariff prices and checkout offers are **not generated in the VPN client**
  until exposed by the server and implemented within Apple billing policy.
- Account profile and connected-device functionality use the current controller.
  A per-device list and 3-device usage counter are not available in
  `TunnelCoreController`; global logout is supported and preserved.
- The five destinations are logically separate views of one account page
  (QML `viewMode`), not independently instantiated backend sessions.

## QA before merging

1. Android/iOS: email login, email registration, PIN login, logout, account
   deletion entry and localized validation messages.
2. Soft keyboard: email, password, password confirmation and country search
   remain reachable above the IME on small mobile screens.
3. Active and inactive connections: the large control retains both connect and
   disconnect behavior, shows live connection state and does not bypass busy
   guards or profile import.
4. Changing country: current country is highlighted, search works, switching
   while connected first disconnects as before, and auto selection works.
5. Subscription: correct live expiry and renewal method; no fictional data.
6. API country selection and device unlink confirmations continue to work.
7. Windows desktop: keyboard/focus navigation; portrait and landscape layouts.
8. Screen-reader focus, tap targets, foreground contrast and QML runtime warnings.
9. Five bottom tabs, welcome/sign-in/sign-out flow, country filter, subscription
   actions and user account sections when authenticated.
10. App/site split tunneling respects mobile platform constraints and existing
   settings; no non-functional per-app toggles on iOS.

This visual migration is intentionally scoped to existing working navigation and
APIs; it is not a wholesale replacement of the VPN application's architecture.
