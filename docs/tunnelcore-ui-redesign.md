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
- Existing real `Home` and `Settings` tabs now have captions; no empty or
  misleading destinations are introduced.

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
- The mockups' standalone onboarding, checkout, profile and five-destination
  navigation are not yet implemented as independent app routes.

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

This visual migration is intentionally scoped to existing working navigation and
APIs; it is not a wholesale replacement of the VPN application's architecture.
