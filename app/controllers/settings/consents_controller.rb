# frozen_string_literal: true

# Settings › Consent: the banner's words, the privacy policy it links to,
# Google Consent Mode, and each Scripts global item's category (Consent).
class Settings::ConsentsController < Settings::BaseController
  include PluginGated
  plugin :consent

  requires_capability "settings:read",  only: :show
  requires_capability "settings:write", only: :update

  def show
    @settings = Consent.settings
    @items = Array(Global.find_by(slug: "scripts")&.data.to_h["items"]).grep(Hash)
  end

  def update
    attrs = params.require(:consent).permit(:banner, :message, :policy_url, :consent_mode, categories: {}).to_h
    attrs["banner"] = attrs["banner"] == "1"
    attrs["consent_mode"] = attrs["consent_mode"] == "1"
    attrs["categories"] = attrs["categories"].to_h.select { |_, category| Consent::CATEGORIES.key?(category) }
    attrs["policy_url"] = "" unless attrs["policy_url"].blank? || SafeUrl.safe?(attrs["policy_url"])

    Setting.changing(Consent::SETTING_KEY) { it.data = Consent.settings.merge(attrs) }
    Event.record("settings.consent_updated", fields: attrs.keys)
    redirect_to settings_consent_path, notice: "Consent saved"
  end
end
