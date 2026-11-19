# The single place layouts and pages ask which public design to render.
module DesignHelper
  def design_preference
    @design_preference ||= DesignPreference.new(
      mode: DesignPreference.mode,
      choice: cookies[DesignPreference::COOKIE]
    )
  end

  def new_design?
    design_preference.new_design?
  end
end
