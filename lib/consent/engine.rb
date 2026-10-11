# frozen_string_literal: true

require "consent/banner"

module Consent
  # A CMS plugin (docs/plugins.md): it extends the core only through
  # Cms::Plugins, and the core never names it.
  class Engine < ::Rails::Engine
    initializer "consent.routes" do |app|
      app.routes.append do
        scope(path: Cms::PATH) do
          namespace :settings do
            resource :consent, only: [:show, :update], controller: "consents"
          end
        end
      end
    end

    config.to_prepare do
      Cms::Plugins.register :consent, name: "Consent", version: "1.0.0", author: "Martin Business Consultants",
        enabled_by_default: false, requires: ">= 1.27",
        description: "A cookie consent banner on the website: the Scripts global's analytics and marketing scripts " \
                     "run only once a visitor agrees."

      # The Scripts global's items, held back by category until a yes.
      Cms::Plugins.filter(:consent, "website.scripts") { |items, part:, **| Consent.filter_items(items, part: part) }
      # The banner, on every page while it's on.
      Cms::Plugins.filter(:consent, "website.body") do |html, **|
        Consent.settings["banner"] ? html + Consent::Banner.html.html_safe : html # rubocop:disable Rails/OutputSafety
      end

      Cms::Plugins.settings :consent, "Consent", -> { settings_consent_path },
        description: "The cookie banner, and which scripts wait for a visitor's consent.", capability: "settings:read",
        group: "Workspace"
    end
  end
end
