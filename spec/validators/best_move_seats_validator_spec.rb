require "rails_helper"

RSpec.describe BestMoveSeatsValidator do
  let(:model_class) do
    Class.new do
      include ActiveModel::Model

      attr_accessor :seats, :seat

      def self.name = "BestMoveSeatsHolder"

      validates :seats, best_move_seats: true
    end
  end
  let(:excluding_model_class) do
    Class.new(model_class) do
      clear_validators!
      validates :seats, best_move_seats: { excluding: :seat }
    end
  end

  describe "shape" do
    subject(:record) { model_class.new(seats: seats) }

    before { record.validate }

    {
      "one seat" => [ 3 ],
      "three distinct seats" => [ 1, 5, 10 ],
      "nothing" => nil
    }.each do |description, value|
      context "with #{description}" do
        let(:seats) { value }

        it "adds no error" do
          expect(record.errors).to be_empty
        end
      end
    end

    {
      "more than three seats" => [ 1, 2, 3, 4 ],
      "an empty list" => [],
      "duplicate seats" => [ 2, 2 ],
      "seats out of range" => [ 0, 11 ],
      "a valid seat mixed with one out of range" => [ 3, 11 ],
      "a non-integer seat" => [ "3" ],
      "a fractional seat" => [ 3.0 ],
      "a non-array value" => 3,
      "a string value" => "3"
    }.each do |description, value|
      context "with #{description}" do
        let(:seats) { value }

        it "adds an invalid error" do
          expect(record.errors).to be_of_kind(:seats, :invalid)
        end
      end
    end
  end

  describe "excluding the own seat" do
    subject(:record) { excluding_model_class.new(seats: seats, seat: own_seat) }

    before { record.validate }

    context "when the own seat is named" do
      let(:seats) { [ 2, 4 ] }
      let(:own_seat) { 4 }

      it "adds an own_seat error" do
        expect(record.errors.details[:seats]).to eq([ { error: :own_seat } ])
      end
    end

    context "when the own seat is not named" do
      let(:seats) { [ 2, 5 ] }
      let(:own_seat) { 4 }

      it "adds no error" do
        expect(record.errors).to be_empty
      end
    end

    context "when the own seat is unknown" do
      let(:seats) { [ 2, 4 ] }
      let(:own_seat) { nil }

      it "adds no error" do
        expect(record.errors).to be_empty
      end
    end

    context "when the value is not a list" do
      let(:seats) { 4 }
      let(:own_seat) { 4 }

      it "adds only the invalid error" do
        expect(record.errors.details[:seats]).to eq([ { error: :invalid } ])
      end
    end
  end
end
