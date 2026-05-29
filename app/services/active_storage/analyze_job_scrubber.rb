class ActiveStorage::AnalyzeJobScrubber
  Result = Data.define(:scanned, :orphaned)

  DEFAULT_SCOPE = -> { SolidQueue::Job.where(class_name: "ActiveStorage::AnalyzeJob", finished_at: nil) }

  def self.call(dry_run: false, scope: DEFAULT_SCOPE.call)
    new(dry_run: dry_run, scope: scope).call
  end

  def initialize(dry_run:, scope:)
    @dry_run = dry_run
    @scope = scope
    @scanned = 0
    @orphaned = 0
  end

  def call
    iterate { |sq_job| handle(sq_job) }
    Result.new(scanned: @scanned, orphaned: @orphaned)
  end

  private

  def iterate(&block)
    if @scope.respond_to?(:find_each)
      @scope.find_each(&block)
    else
      @scope.each(&block)
    end
  end

  def handle(sq_job)
    @scanned += 1
    blob_id = extract_blob_id(sq_job.arguments)
    return if blob_id.nil?

    blob = ::ActiveStorage::Blob.find_by(id: blob_id)
    reason = orphan_reason(blob)
    return if reason.nil?

    @orphaned += 1
    log(sq_job, blob_id, reason)
    sq_job.discard unless @dry_run
  end

  def orphan_reason(blob)
    return "blob row missing" if blob.nil?
    return "blob file missing" unless blob.service.exist?(blob.key)

    nil
  end

  def extract_blob_id(arguments)
    gid = arguments.dig("arguments", 0, "_aj_globalid")
    return nil if gid.blank?

    Integer(gid.split("/").last, 10)
  rescue ArgumentError, TypeError
    nil
  end

  def log(sq_job, blob_id, reason)
    Rails.logger.warn(
      {
        event: "active_storage.scrub.orphan_analyze_job",
        sq_job_id: sq_job.id,
        blob_id: blob_id,
        reason: reason,
        dry_run: @dry_run
      }.to_json
    )
  end
end
