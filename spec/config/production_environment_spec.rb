require "rails_helper"

RSpec.describe "config/environments/production.rb host validation" do
  let(:config) do
    c = ActiveSupport::OrderedOptions.new
    c.hosts = []
    c
  end

  def evaluate_production_hosts_block
    source = Rails.root.join("config/environments/production.rb").read
    match = source.match(/Rails\.application\.configure do\n(.*)\nend\n\z/m)
    raise "Could not find Rails.application.configure block" unless match

    body = match[1]
    host_section = body.match(/^  # Enable DNS rebinding protection.*?^  config\.host_authorization = [^\n]+$/m)
    raise "Could not find host config section" unless host_section

    config_ref = config
    eval_context = Object.new
    eval_context.define_singleton_method(:config) { config_ref }
    eval_context.instance_eval(host_section[0])
  end

  around do |example|
    original_host = ENV["APPLICATION_HOST"]
    ENV["APPLICATION_HOST"] = nil
    example.run
  ensure
    ENV["APPLICATION_HOST"] = original_host
  end

  it "whitelists the canonical production domain" do
    evaluate_production_hosts_block
    expect(config.hosts).to include("vanilla-mafia.ru")
  end

  it "whitelists subdomains of the production domain" do
    evaluate_production_hosts_block
    subdomain_matcher = config.hosts.find { |h| h.is_a?(Regexp) }
    expect(subdomain_matcher).to match("www.vanilla-mafia.ru")
    expect(subdomain_matcher).not_to match("evil.example.com")
  end

  it "appends APPLICATION_HOST when present" do
    ENV["APPLICATION_HOST"] = "staging.example.com"
    evaluate_production_hosts_block
    expect(config.hosts).to include("staging.example.com")
  end

  it "does not append APPLICATION_HOST when blank" do
    ENV["APPLICATION_HOST"] = ""
    evaluate_production_hosts_block
    expect(config.hosts).not_to include("")
  end

  it "excludes the /up health check from host authorization" do
    evaluate_production_hosts_block
    request = Struct.new(:path).new("/up")
    expect(config.host_authorization[:exclude].call(request)).to be true
  end

  it "enforces host authorization for non-health-check paths" do
    evaluate_production_hosts_block
    request = Struct.new(:path).new("/admin")
    expect(config.host_authorization[:exclude].call(request)).to be false
  end
end
