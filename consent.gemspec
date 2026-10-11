# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "consent"
  spec.version = "1.1.0"
  spec.summary = "A cookie consent banner for LibrePublish CMS: the Scripts global's analytics and marketing scripts wait for a visitor's yes"
  spec.authors = ["Martin Business Consultants"]
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
