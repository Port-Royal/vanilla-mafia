# Decides per request which public design a visitor sees, from the
# `public_redesign` toggle mode and the visitor's `design` cookie.
class DesignPreference
  TOGGLE_KEY = "public_redesign"
  COOKIE = :design
  CHOICES = %w[new old].freeze
  EVERYONE = "everyone"

  def self.mode
    return :off unless FeatureToggle.enabled?(TOGGLE_KEY)

    FeatureToggle.value_for(TOGGLE_KEY) == EVERYONE ? :everyone : :opt_in
  end

  def initialize(mode:, choice:)
    @mode = mode
    @choice = CHOICES.include?(choice) ? choice : nil
  end

  def new_design?
    @mode == :everyone || chose?("new")
  end

  def offer?
    opt_in? && @choice.nil?
  end

  def switch_to_new?
    chose?("old")
  end

  def switch_to_old?
    chose?("new")
  end

  private

  def opt_in?
    @mode == :opt_in
  end

  def chose?(choice)
    opt_in? && @choice == choice
  end
end
