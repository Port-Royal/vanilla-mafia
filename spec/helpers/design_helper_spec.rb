require "rails_helper"

RSpec.describe DesignHelper do
  describe "#new_design?" do
    context "when the redesign is off" do
      before { helper.request.cookies[:design] = "new" }

      it { expect(helper.new_design?).to be(false) }
    end

    context "with the redesign offered" do
      include_context "with the redesign offered"

      context "when the visitor chose the new design" do
        before { helper.request.cookies[:design] = "new" }

        it { expect(helper.new_design?).to be(true) }
      end

      context "when the visitor chose the old design" do
        before { helper.request.cookies[:design] = "old" }

        it { expect(helper.new_design?).to be(false) }
      end

      context "without a design cookie" do
        it { expect(helper.new_design?).to be(false) }
      end
    end

    context "with the new design" do
      include_context "with the new design"

      context "when the visitor chose the old design" do
        before { helper.request.cookies[:design] = "old" }

        it { expect(helper.new_design?).to be(true) }
      end

      context "without a design cookie" do
        it { expect(helper.new_design?).to be(true) }
      end
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
