# frozen_string_literal: true

module Consent
  # The banner, for the end of every page's <body> (the website.body filter):
  # Accept all, Only necessary, or a choice per category, remembered in the
  # lp_consent cookie for a year. Its script brings the held items to life
  # (Consent.hold) for what's accepted, tells Google's tags (Consent Mode),
  # and opens again from any link to #cookie-settings.
  module Banner
    module_function

    def html(settings = Consent.settings)
      h = ->(text) { ERB::Util.h(text) }
      policy = settings["policy_url"].presence
      choices = Consent::CATEGORIES.except("necessary").map do |key, label|
        %(<label class="lp-consent__choice"><input type="checkbox" value="#{h.(key)}"> #{h.(label)}</label>)
      end.join

      <<~HTML
        <div class="lp-consent" role="dialog" aria-live="polite" aria-label="Cookie consent" hidden data-lp-consent>
          <p class="lp-consent__text">#{h.(settings["message"])}#{%( <a href="#{h.(policy)}">Privacy policy</a>) if policy}</p>
          <div class="lp-consent__choices" hidden data-lp-consent-choices>
            <label class="lp-consent__choice"><input type="checkbox" checked disabled> Necessary</label>
            #{choices}
          </div>
          <div class="lp-consent__actions">
            <button type="button" data-lp-consent-action="choose">Choose</button>
            <button type="button" data-lp-consent-action="save" hidden>Save choices</button>
            <button type="button" data-lp-consent-action="necessary">Only necessary</button>
            <button type="button" data-lp-consent-action="all" class="lp-consent__primary">Accept all</button>
          </div>
        </div>
        <style>#{STYLE}</style>
        <script>#{SCRIPT}</script>
      HTML
    end

    STYLE = <<~CSS.squish
      .lp-consent { position: fixed; z-index: 2147483000; left: 1rem; right: 1rem; bottom: 1rem; max-width: 40rem; margin: 0 auto;
        padding: 1rem 1.25rem; border-radius: 0.75rem; background: #fff; color: #1c1917; box-shadow: 0 10px 30px rgb(0 0 0 / 0.2);
        font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
      .lp-consent[hidden] { display: none; }
      .lp-consent__text { margin: 0 0 0.75rem; }
      .lp-consent__text a { color: inherit; text-decoration: underline; }
      .lp-consent__choices { display: flex; flex-wrap: wrap; gap: 0.5rem 1.25rem; margin: 0 0 0.75rem; }
      .lp-consent__choices[hidden] { display: none; }
      .lp-consent__choice { display: inline-flex; align-items: center; gap: 0.4rem; }
      .lp-consent__actions { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 0.5rem; }
      .lp-consent__actions button { padding: 0.5rem 0.9rem; border: 1px solid #d6d3d1; border-radius: 0.5rem; background: #fff; color: inherit;
        font: inherit; font-weight: 600; cursor: pointer; }
      .lp-consent__actions button[hidden] { display: none; }
      .lp-consent__actions .lp-consent__primary { border-color: #1c1917; background: #1c1917; color: #fff; }
    CSS

    SCRIPT = <<~JS
      (() => {
        const KEY = "lp_consent"
        const banner = document.querySelector("[data-lp-consent]")
        if (!banner) return
        const choices = banner.querySelector("[data-lp-consent-choices]")
        const boxes = [...choices.querySelectorAll("input[value]")]

        const read = () => {
          const found = document.cookie.match(/(?:^|; )lp_consent=([^;]*)/)
          return found ? decodeURIComponent(found[1]).split(",").filter(Boolean) : null
        }
        const write = accepted => {
          document.cookie = `${KEY}=${encodeURIComponent(accepted.join(",") || "necessary")}; path=/; max-age=31536000; samesite=lax` +
            (location.protocol === "https:" ? "; secure" : "")
        }

        // The held items of the categories accepted, brought to life in page order.
        const activate = accepted => {
          document.querySelectorAll("script[data-consent]").forEach(held => {
            if (held.dataset.consentDone || !accepted.includes(held.dataset.consent)) return
            const script = document.createElement("script")
            for (const attribute of held.attributes) {
              if (!["type", "data-consent", "data-consent-type"].includes(attribute.name)) script.setAttribute(attribute.name, attribute.value)
            }
            if (held.dataset.consentType) script.type = held.dataset.consentType
            script.async = false
            script.text = held.text
            held.dataset.consentDone = "1"
            held.after(script)
          })
          document.querySelectorAll("[data-consent-src]").forEach(element => {
            if (!accepted.includes(element.dataset.consent)) return
            element.src = element.dataset.consentSrc
            element.removeAttribute("data-consent-src")
          })
          if (typeof window.gtag === "function") {
            const granted = key => accepted.includes(key) ? "granted" : "denied"
            window.gtag("consent", "update", { analytics_storage: granted("analytics"), ad_storage: granted("marketing"),
              ad_user_data: granted("marketing"), ad_personalization: granted("marketing") })
          }
        }

        const choose = accepted => { write(accepted); activate(accepted); banner.hidden = true }
        const open = () => {
          const accepted = read() || []
          boxes.forEach(box => { box.checked = accepted.includes(box.value) })
          banner.hidden = false
        }

        banner.addEventListener("click", event => {
          const action = event.target.closest("[data-lp-consent-action]")?.dataset.lpConsentAction
          if (action === "all") choose(boxes.map(box => box.value))
          else if (action === "necessary") choose([])
          else if (action === "save") choose(boxes.filter(box => box.checked).map(box => box.value))
          else if (action === "choose") {
            choices.hidden = false
            banner.querySelector('[data-lp-consent-action="choose"]').hidden = true
            banner.querySelector('[data-lp-consent-action="save"]').hidden = false
          }
        })
        document.addEventListener("click", event => {
          if (event.target.closest('a[href="#cookie-settings"]')) { event.preventDefault(); open() }
        })
        window.lpConsent = { open }

        const accepted = read()
        if (accepted) activate(accepted)
        else banner.hidden = false
      })()
    JS
  end
end
