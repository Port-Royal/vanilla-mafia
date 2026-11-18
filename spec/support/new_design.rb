# Switch a request or helper spec to the redesigned public site.
RSpec.shared_context "with the new design" do
  let_it_be(:public_redesign_toggle) do
    create(:feature_toggle, key: DesignPreference::TOGGLE_KEY, enabled: true, value: "everyone")
  end
end

# Offer the redesign: visitors see the new design only after choosing it.
RSpec.shared_context "with the redesign offered" do
  let_it_be(:public_redesign_toggle) do
    create(:feature_toggle, key: DesignPreference::TOGGLE_KEY, enabled: true, value: "opt_in")
  end
end
