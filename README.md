# Consent

A cookie consent banner for Libre Publish. The Scripts global's items (analytics, a chat widget, an ad pixel) run only once a visitor agrees to their kind.

- **Settings › Consent**: the banner's words, the privacy policy it links to, Google Consent Mode, and each Scripts item's kind: Necessary (runs as always), Analytics or Marketing. An item not given a kind waits as Analytics.
- **On the website**: items that wait are printed inert (a `<script>` as `text/plain`, an iframe's or pixel's address held back). The banner offers Accept all, Only necessary, or a choice per kind, kept a year in the `lp_consent` cookie, and brings what's accepted to life. A link to `#cookie-settings` opens it again; so does `window.lpConsent.open()`.
- **Google Consent Mode v2**: Google's tags start with everything denied and follow the visitor's choice.
- Pages are cached for everyone, so a page never differs by the visitor's choice: the browser decides.

Needs Libre Publish 1.27 or later (the `website.scripts` filter). Install from Settings › Plugins.
