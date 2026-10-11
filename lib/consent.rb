# frozen_string_literal: true

require "consent/engine"

# Consent: the Scripts global's items (analytics, a chat widget, a pixel) run
# only once a visitor agrees to their category, asked by a banner on the
# website. A plugin (docs/plugins.md): it works through the core's
# website.scripts and website.body filters.
#
# Each item has a category (Settings › Consent): necessary ones run as
# always; the others are printed inert — a <script> as text/plain, an
# iframe's or image's address held back — and the banner's script brings
# them to life for the categories accepted. The choice is kept in the
# lp_consent cookie for a year. Pages are cached for everyone, so the server
# never varies a page by that cookie: the browser decides.
module Consent
  SETTING_KEY = "consent_settings"
  CATEGORIES = {"necessary" => "Necessary", "analytics" => "Analytics", "marketing" => "Marketing"}.freeze
  # An item no one has given a category waits for consent: nothing new runs
  # before someone says it may.
  DEFAULT_CATEGORY = "analytics"
  DEFAULTS = {
    "banner" => true,
    "message" => "We use cookies to see how the site is used and to improve it. Necessary ones keep it working; the rest only with your consent.",
    "policy_url" => "",
    "consent_mode" => true,
    "categories" => {}
  }.freeze
  SCRIPT_TYPES = ["", "text/javascript", "application/javascript", "module"].freeze

  module_function

  def settings = DEFAULTS.merge(Setting.get(SETTING_KEY).to_h)

  def category_for(item)
    settings["categories"].to_h[item["name"].to_s].presence_in(CATEGORIES.keys) || DEFAULT_CATEGORY
  end

  # The website.scripts filter: each item held back unless it's necessary,
  # and, in the head, Google's consent defaults first.
  def filter_items(items, part:)
    held = items.map do |item|
      category = category_for(item)
      next item if category == "necessary"

      item.merge(part => hold(item[part].to_s, category))
    end
    part == "head" && settings["consent_mode"] ? [consent_mode_item, *held] : held
  end

  # HTML whose scripts don't run and whose frames and pixels don't load
  # until the banner's script lets `category` go.
  def hold(html, category)
    return html if html.blank?

    fragment = Nokogiri::HTML5::DocumentFragment.parse(html)
    fragment.css("script").each do |script|
      type = script["type"].to_s.strip.downcase
      next unless SCRIPT_TYPES.include?(type)

      script["data-consent"] = category
      script["data-consent-type"] = script["type"].to_s
      script["type"] = "text/plain"
    end
    fragment.css("iframe[src], img[src], embed[src]").each do |element|
      element["data-consent"] = category
      element["data-consent-src"] = element["src"]
      element.remove_attribute("src")
    end
    fragment.to_html
  end

  # Google Consent Mode v2: everything denied until the visitor chooses
  # (the banner's script updates it), so Google's tags start quiet.
  def consent_mode_item
    {"name" => "Consent defaults", "head" => <<~HTML}
      <script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag("consent","default",{ad_storage:"denied",ad_user_data:"denied",ad_personalization:"denied",analytics_storage:"denied",wait_for_update:500});</script>
    HTML
  end
end
