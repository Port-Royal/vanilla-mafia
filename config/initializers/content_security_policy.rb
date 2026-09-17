# Be sure to restart your server when you modify this file.
#
# Application-wide Content-Security-Policy.
#
# ENFORCED (sets Content-Security-Policy). Browsers block violations rather than
# only logging them, and still POST JSON reports to `report-uri`
# (CspViolationReportsController#create), which forwards them to Sentry.
#
# The policy shipped report-only first and was promoted once production had been
# reporting cleanly (vm-1rb / #819). Loosen a directive rather than leave a real
# violation blocked — a blocked resource is now a broken page, not a log line.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self, :https
    policy.style_src       :self, :https, :unsafe_inline
    policy.img_src         :self, :https, :data, :blob # blob: — Trix editor image-attachment previews
    policy.font_src        :self, :https, :data
    policy.connect_src     :self, :https
    policy.object_src      :none
    policy.base_uri        :self
    policy.frame_ancestors :none
    policy.form_action     :self, "https://accounts.google.com"
    policy.report_uri      "/csp_violation_reports"
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  config.content_security_policy_report_only = false
end
