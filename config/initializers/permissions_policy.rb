require Rails.root.join("app/middleware/permissions_policy_header")

Rails.application.config.middleware.use PermissionsPolicyHeader
