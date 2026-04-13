source_token = ENV["BETTER_STACK_SOURCE_TOKEN"]
ingesting_host = ENV["BETTER_STACK_INGESTING_HOST"]

if source_token.present? && ingesting_host.present?
  logtail_logger = Logtail::Logger.create_default_logger(source_token, ingesting_host: ingesting_host)
  Rails.logger.broadcast_to(logtail_logger)
end
