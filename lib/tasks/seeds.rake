namespace :seeds do
  desc "Validate that all FeatureToggle keys are present in db/seeds.rb"
  task :validate do
    root = File.expand_path("../..", __dir__)
    seeds_content = File.read(File.join(root, "db/seeds.rb"))
    model_content = File.read(File.join(root, "app/models/feature_toggle.rb"))

    match = model_content.match(/KEYS\s*=\s*%w\[([^\]]*)\]/)
    abort "Could not find FeatureToggle::KEYS in app/models/feature_toggle.rb" unless match

    keys = match[1].split
    missing_keys = keys.reject { |key| seeds_content.include?(key) }

    abort "Missing feature toggle seeds: #{missing_keys.join(', ')}" if missing_keys.any?

    puts "All #{keys.size} feature toggle key(s) are present in db/seeds.rb"
  end
end
