# Google Play store listing: TunnelCore VPN

These files are **drafts for the Google Play listing**, not the app's interface translations.

- The app title stays exactly `TunnelCore VPN` in every locale.
- Only the **short** and **full** store descriptions are localized.
- No graphics, icons, screenshots, in-app strings, or Android TV screenshots are changed.
- Available languages: `en-US`, `ru-RU`, `tr-TR`, `ur`, `es-419`, `pt-BR`, `de-DE`, `fr-FR`, `ar`, `id`, `hi-IN`, `ka-GE`.
- Keep the source listing (`en-US`) up to date before translating further.
- Limits: title <= 30, short description <= 80, full description <= 4000 characters.
- In the Google Play Console, select **Grow users -> Store presence -> Store listings**, then choose **Manage translations -> Select languages** and paste the corresponding texts. Google Play supports the locales in this directory.
- **Git changes do not publish or synchronize the Play Console listing.** The existing `Android Play Release` workflow only builds an AAB; descriptions must be entered/reviewed in Play Console unless a separate publishing integration is configured.
- Descriptions refer to split tunneling only on supported Android phones/tablets, not Android TV.
- Do not add claims such as "no logs", "unlimited", "100% anonymous", or "fastest VPN" without verifying them.
- Review human translations before publishing, particularly Urdu, Georgian, Arabic and Hindi. Any translated description should match what users can actually do in the app.
- A translated store listing does not mean the Android app's UI supports that language.

To use a locale, copy `metadata/<locale>/short_description.txt` and `metadata/<locale>/full_description.txt` into the corresponding Google Play Console fields. The `title.txt` is intentionally unchanged in all locales.
