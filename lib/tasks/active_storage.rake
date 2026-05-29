namespace :active_storage do
  desc "Discard queued AnalyzeJob entries whose blob row or file is missing. DRY_RUN=1 to preview."
  task scrub_orphan_analyze_jobs: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    result = ActiveStorage::AnalyzeJobScrubber.call(dry_run: dry_run)
    puts "scanned=#{result.scanned} orphaned=#{result.orphaned} dry_run=#{dry_run}"
  end
end
