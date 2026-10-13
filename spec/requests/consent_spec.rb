# frozen_string_literal: true

require "rails_helper"

# The Scripts global's items wait for a visitor's consent, by kind, and the
# banner asks for it.
RSpec.describe "The Consent plugin", type: :request do
  let(:admin) { create(:user) }

  around do |example|
    registered = Website.theme
    Website.register :fixture, name: "Fixture", version: "1", views: Rails.root.join("spec/fixtures/website_theme/views")
    example.run
  ensure
    Website.theme = registered
  end

  before do
    BlockType::Defaults.install!
    Page.create!(slug: "home", title: "Home", status: "published", locale: "en")
    switch_plugin :consent, on: true
    Global.create!(slug: "scripts", name: "Scripts", schema: {"fields" => []}, data: {"items" => [
      {"name" => "GA4", "head" => %(<script async src="https://www.googletagmanager.com/gtag/js?id=G-1"></script><script>gtag("config","G-1")</script>)},
      {"name" => "Pixel", "body" => %(<img src="https://px.example/p.gif" alt="">)},
      {"name" => "Fonts", "head" => %(<link rel="stylesheet" href="https://fonts.example/a.css"><script>fonts()</script>)}
    ]})
    Setting.set(Consent::SETTING_KEY, {"categories" => {"Pixel" => "marketing", "Fonts" => "necessary"}})
  end

  it "holds each item back by its kind, until the banner's script lets it go" do
    get "/"
    page = Nokogiri::HTML5(response.body)

    # Consent Mode is on: Google's tag runs, quiet until the visitor agrees, so Google sees it installed.
    expect(page.css("script[data-consent=analytics]")).to be_empty
    expect(page.at("script[src*=googletagmanager]")["type"]).to be_nil
    expect(response.body).to include('<script>gtag("config","G-1")</script>')
    expect(page.at("img[data-consent=marketing]")["src"]).to be_nil
    expect(page.at("img[data-consent=marketing]")["data-consent-src"]).to include("px.example")
    expect(response.body).to include("<script>fonts()</script>")
    expect(response.body).to include('gtag("consent","default"')
    expect(page.at("[data-lp-consent]")).to be_present
  end

  it "holds Google's tag back too when Consent Mode is off, and still holds others' scripts with it" do
    Setting.set(Consent::SETTING_KEY, {"consent_mode" => false})
    get "/"
    ga = Nokogiri::HTML5(response.body).css("script[data-consent=analytics]")
    expect(ga.map { it["type"] }).to all(eq("text/plain"))
    expect(ga.first["src"]).to include("googletagmanager")

    Setting.set(Consent::SETTING_KEY, {"consent_mode" => true})
    Global.find_by!(slug: "scripts").update!(data: {"items" => [{"name" => "Mixed", "head" => %(<script>gtag("config","G-1")</script><script src="https://connect.facebook.net/fbevents.js"></script><script>fbq("init","1")</script>)}]})
    get "/"
    page = Nokogiri::HTML5(response.body)
    expect(page.css("script[data-consent=analytics]").map { it["src"] || it.text }).to contain_exactly("https://connect.facebook.net/fbevents.js", %(fbq("init","1")))
  end

  it "is chosen in Settings › Consent: the words, the policy, and each item's kind" do
    sign_in_as admin
    get settings_consent_path
    expect(response.body).to include("Which scripts wait", "GA4", "Pixel")

    patch settings_consent_path, params: {consent: {banner: "1", message: "Cookies?", policy_url: "javascript:alert(1)", consent_mode: "0",
      categories: {"GA4" => "necessary", "Pixel" => "bogus"}}}
    expect(Consent.settings).to include("message" => "Cookies?", "policy_url" => "", "consent_mode" => false)
    expect(Consent.settings["categories"]).to eq("GA4" => "necessary")

    get "/"
    expect(response.body).to include(%(gtag("config","G-1")</script>))
    expect(response.body).not_to include('gtag("consent","default"')
  end

  it "changes nothing while it's off" do
    switch_plugin :consent, on: false
    get "/"
    expect(response.body).not_to include("data-consent", "data-lp-consent")
  end
end
