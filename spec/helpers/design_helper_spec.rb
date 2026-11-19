require "rails_helper"

RSpec.describe DesignHelper do
  # Each mode runs the whole cookie table: cookie => [new_design?, offer?].
  shared_examples "a design for every cookie" do |table|
    table.each do |cookie, (new_design, offer)|
      context "with design cookie #{cookie.inspect}" do
        before { helper.request.cookies[:design] = cookie unless cookie.nil? }

        it { expect(helper.new_design?).to be(new_design) }
        it { expect(helper.design_preference.offer?).to be(offer) }
      end
    end
  end

  describe "#new_design?" do
    context "without a redesign toggle" do
      it_behaves_like "a design for every cookie",
                      nil => [ false, false ], "new" => [ false, false ], "old" => [ false, false ],
                      "beta" => [ false, false ], "" => [ false, false ]
    end

    context "with the redesign toggle disabled" do
      let_it_be(:public_redesign_toggle) do
        create(:feature_toggle, key: DesignPreference::TOGGLE_KEY, enabled: false, value: "everyone")
      end

      it_behaves_like "a design for every cookie",
                      nil => [ false, false ], "new" => [ false, false ], "old" => [ false, false ],
                      "beta" => [ false, false ], "" => [ false, false ]
    end

    context "with the redesign offered" do
      include_context "with the redesign offered"

      it_behaves_like "a design for every cookie",
                      nil => [ false, true ], "new" => [ true, false ], "old" => [ false, false ],
                      "beta" => [ false, true ], "" => [ false, true ]
    end

    context "with the new design" do
      include_context "with the new design"

      it_behaves_like "a design for every cookie",
                      nil => [ true, false ], "new" => [ true, false ], "old" => [ true, false ],
                      "beta" => [ true, false ], "" => [ true, false ]
    end
  end

  describe "#design_preference" do
    context "with the redesign offered and no choice yet" do
      include_context "with the redesign offered"

      it { expect(helper.design_preference).to be_a(DesignPreference) }
      it { expect(helper.design_preference.offer?).to be(true) }
      it { expect(helper.design_preference).to equal(helper.design_preference) }
    end

    context "with the redesign offered and the old design chosen" do
      include_context "with the redesign offered"

      before { helper.request.cookies[:design] = "old" }

      it { expect(helper.design_preference.switch_to_new?).to be(true) }
    end
  end
end
