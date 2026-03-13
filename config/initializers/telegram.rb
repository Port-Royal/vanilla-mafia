Rails.application.config.x.telegram = ActiveSupport::OrderedOptions.new
bot_token = Rails.application.credentials.dig(:telegram, :bot_token)

if Rails.env.production? && bot_token.blank?
  raise "Telegram bot token is missing or blank. Please set credentials.telegram.bot_token."
end

Rails.application.config.x.telegram.bot_token = bot_token
