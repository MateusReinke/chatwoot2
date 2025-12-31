# frozen_string_literal: true

# EagleTalks - Brand Config Central
# Single source of truth for whitelabel values.
#
# Keep changes minimal for easy upstream rebases.
# Do not reference /enterprise code.

Rails.application.config.x.brand = ActiveSupport::OrderedOptions.new

brand = Rails.application.config.x.brand

brand.name = ENV.fetch("APP_BRAND_NAME", "EagleTalks")
brand.url = ENV.fetch("APP_BRAND_URL", "https://eagletelecom.cloud")
brand.support_url = ENV["APP_SUPPORT_URL"].presence || brand.url
brand.docs_url = ENV["APP_DOCS_URL"].presence
brand.terms_url = ENV["APP_TERMS_URL"].presence
brand.privacy_url = ENV["APP_PRIVACY_URL"].presence

brand.hide_powered_by = ActiveModel::Type::Boolean.new.cast(ENV.fetch("APP_HIDE_POWERED_BY", "true"))
brand.hide_docs_links = ActiveModel::Type::Boolean.new.cast(ENV.fetch("APP_HIDE_DOCS_LINKS", "true"))

brand.email_footer_text = ENV.fetch("APP_EMAIL_FOOTER_TEXT", "#{brand.name} • Eagle Telecom")
