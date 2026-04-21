# Be sure to restart your server when you modify this file.
#
# Application-wide Content-Security-Policy.
#
# Currently shipping in REPORT-ONLY mode (sets Content-Security-Policy-Report-Only).
# Browsers will log violations to the devtools console and POST JSON reports to
# `report-uri` (CspViolationReportsController#create) without blocking anything.
# Once we've been collecting clean reports from production for ~1–2 weeks, the
# enforcement follow-up (vm-1rb) flips `content_security_policy_report_only` to
# false.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self, :https
    policy.style_src       :self, :https, :unsafe_inline
    policy.img_src         :self, :https, :data
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

  config.content_security_policy_report_only = true
end
