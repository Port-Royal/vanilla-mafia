source_token = ENV["BETTER_STACK_SOURCE_TOKEN"]
ingesting_host = ENV["BETTER_STACK_INGESTING_HOST"]

if Rails.env.production? && source_token.present? && ingesting_host.present?
  logtail_logger = Logtail::Logger.create_default_logger(source_token, ingesting_host: ingesting_host)

  if Rails.logger.respond_to?(:broadcast_to)
    Rails.logger.broadcast_to(logtail_logger)
  else
    Rails.logger = ActiveSupport::BroadcastLogger.new(Rails.logger, logtail_logger)
  end
end
