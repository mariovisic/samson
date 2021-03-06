# frozen_string_literal: true
class SlackWebhook < ActiveRecord::Base
  validate :validate_url

  belongs_to :stage

  scope :for_buddy, -> { where(for_buddy: true) }

  def deliver_for?(deploy_phase, deploy)
    case deploy_phase
    when :for_buddy then for_buddy?
    when :before_deploy then before_deploy?
    when :after_deploy then after_deploy? && (!only_on_failure? || !deploy.succeeded?)
    else raise
    end
  end

  private

  def validate_url
    valid = webhook_url.start_with?('http') && begin
      URI.parse(webhook_url)
    rescue URI::InvalidURIError
      false
    end

    errors.add(:webhook_url, "is invalid") unless valid
  end
end
