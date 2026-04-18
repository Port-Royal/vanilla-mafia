class PermissionsPolicyHeader
  HEADER_NAME = "Permissions-Policy"
  HEADER_VALUE = [
    "camera=()",
    "microphone=()",
    "geolocation=()",
    "gyroscope=()",
    "usb=()",
    "payment=()",
    "fullscreen=(self)"
  ].join(", ").freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers[HEADER_NAME] ||= HEADER_VALUE
    [ status, headers, body ]
  end
end
