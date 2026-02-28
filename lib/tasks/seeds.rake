namespace :seeds do
  desc "Validate that all FeatureToggle keys are present in db/seeds.rb"
  task :validate do
    root = File.expand_path("../..", __dir__)
    seeds_content = File.read(File.join(root, "db/seeds.rb"))
    model_content = File.read(File.join(root, "app/models/feature_toggle.rb"))

    match =
      model_content.match(/KEYS\s*=\s*%w\[(.*?)\]/m) || # KEYS = %w[foo bar]
      model_content.match(/KEYS\s*=\s*%w\((.*?)\)/m) || # KEYS = %w(foo bar)
      model_content.match(/KEYS\s*=\s*\[(.*?)\]/m)      # KEYS = ["foo", "bar"]
    abort "Could not find FeatureToggle::KEYS in app/models/feature_toggle.rb" unless match

    keys_source = match[1]
    keys =
      if match[0].include?("%w")
        keys_source.split
      else
        keys_source.scan(/["']([^"']+)["']/).flatten
      end
    missing_keys = keys.reject { |key| seeds_content.include?(key) }

    abort "Missing feature toggle seeds: #{missing_keys.join(', ')}" if missing_keys.any?

    puts "All #{keys.size} feature toggle key(s) are present in db/seeds.rb"
  end
end
