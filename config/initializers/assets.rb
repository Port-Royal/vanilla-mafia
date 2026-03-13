# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

Rails.application.config.assets.configure do |env|
  mime_type = 'application/manifest+json'
  extensions = ['.webmanifest']

  if Sprockets::VERSION.to_i >= 4
    extensions << '.webmanifest.erb'
    env.register_preprocessor(mime_type, Sprockets::ERBProcessor)
  end

  env.register_mime_type(mime_type, extensions:)
end
