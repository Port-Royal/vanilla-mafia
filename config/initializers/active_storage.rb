Rails.application.config.after_initialize do
  ActiveStorage::AnalyzeJob.discard_on ActiveStorage::FileNotFoundError do |job, error|
    Rails.logger.warn(
      {
        event: "active_storage.analyze_job.file_missing",
        job_id: job.job_id,
        blob_id: job.arguments.first&.id,
        error: error.message
      }.to_json
    )
  end
end
