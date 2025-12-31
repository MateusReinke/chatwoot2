class ApplicationController < ActionController::Base
  include DeviseTokenAuth::Concerns::SetUserByToken
  include RequestExceptionHandler
  include Pundit::Authorization
  include SwitchLocale

  skip_before_action :verify_authenticity_token

  before_action :set_current_user, unless: :devise_controller?
  around_action :switch_locale
  around_action :handle_with_exception, unless: :devise_controller?

  private

  def set_current_user
    @user ||= current_user
    Current.user = @user
  end

  def pundit_user
    {
      user: Current.user,
      account: Current.account,
      account_user: Current.account_user
    }
  end

  # EagleTalks - Brand overrides injected into global config
  # Values come from config/initializers/eagletalks_brand.rb
  def eagletalks_brand_overrides
    brand = Rails.application.config.x.brand

    {
      'BRAND_NAME' => brand.name,
      'BRAND_URL' => brand.url,
      'WIDGET_BRAND_URL' => brand.support_url,
      'INSTALLATION_NAME' => brand.name,

      # Extra URLs and flags for whitelabel (used by frontend patches)
      'SUPPORT_URL' => brand.support_url,
      'DOCS_URL' => brand.docs_url,
      'TERMS_URL' => brand.terms_url,
      'PRIVACY_URL' => brand.privacy_url,
      'HIDE_POWERED_BY' => brand.hide_powered_by,
      'HIDE_DOCS_LINKS' => brand.hide_docs_links,
      'EMAIL_FOOTER_TEXT' => brand.email_footer_text
    }.compact
  end
end

ApplicationController.include_mod_with('Concerns::ApplicationControllerConcern')
