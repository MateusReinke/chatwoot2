class Internal::CheckNewVersionsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    return unless Rails.env.production?

    latest_version = fetch_latest_github_release
    update_version_info(latest_version) if latest_version.present?
  end

  private

  def fetch_latest_github_release
    response = HTTParty.get('https://api.github.com/repos/fazer-ai/chatwoot/releases/latest', timeout: 5)
    unless response.success?
      Rails.logger.error "Failed to fetch latest GitHub release: HTTP #{response.code} - #{response.body}"
      return nil
    end

    response['tag_name']&.sub(/^v/, '')
  rescue StandardError => e
    Rails.logger.error "Failed to fetch latest GitHub release: #{e.message}"
    nil
  end

  def update_version_info(version)
    return if version.blank?

    ::Redis::Alfred.set(::Redis::Alfred::LATEST_CHATWOOT_VERSION, version)
  end
end

Internal::CheckNewVersionsJob.prepend_mod_with('Internal::CheckNewVersionsJob')
