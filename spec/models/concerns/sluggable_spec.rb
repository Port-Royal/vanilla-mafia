require "rails_helper"

RSpec.describe Sluggable do
  # Build an in-memory AR model backed by a temp table so we can exercise
  # Sluggable without coupling the spec to any real model.
  before(:all) do
    ActiveRecord::Base.connection.create_table(:sluggable_test_records, force: true) do |t|
      t.string :name
      t.string :slug
      t.boolean :published, default: false
      t.timestamps
    end

    test_class = Class.new(ApplicationRecord) do
      self.table_name = "sluggable_test_records"
      include Sluggable
      slug_source :name
    end
    Object.const_set(:SluggableTestRecord, test_class)
  end

  after(:all) do
    Object.send(:remove_const, :SluggableTestRecord) if Object.const_defined?(:SluggableTestRecord)
    ActiveRecord::Base.connection.drop_table(:sluggable_test_records)
  end

  def build_record(attrs = {})
    SluggableTestRecord.new({ name: "Ivan" }.merge(attrs))
  end

  describe "slug generation" do
    it "sets slug from the source attribute on create" do
      record = build_record(name: "Alex")
      record.save!
      expect(record.slug).to eq("alex")
    end

    it "transliterates Cyrillic source via CyrillicTransliterator" do
      record = build_record(name: "Иван Петров")
      record.save!
      expect(record.slug).to eq("ivan-petrov")
    end

    it "downcases and parameterizes" do
      record = build_record(name: "Alex Smith")
      record.save!
      expect(record.slug).to eq("alex-smith")
    end

    it "does not regenerate the slug on subsequent saves with a different source" do
      record = build_record(name: "Alex")
      record.save!
      original_slug = record.slug

      record.update!(name: "Bob")
      expect(record.slug).to eq(original_slug)
    end
  end

  describe "#to_param" do
    it "returns the slug" do
      record = build_record(name: "Alex")
      record.save!
      expect(record.to_param).to eq("alex")
    end
  end

  describe "collision handling" do
    it "appends a hex tail when a conflicting slug already exists" do
      first = build_record(name: "Alex")
      first.save!

      second = build_record(name: "Alex")
      second.save!

      expect(second.slug).to match(/\Aalex-[0-9a-f]{4}\z/)
      expect(second.slug).not_to eq(first.slug)
    end

    it "keeps adding new tails if the first tail collides" do
      taken = %w[alex alex-aaaa alex-bbbb]
      taken.each { |slug| SluggableTestRecord.create!(name: "seed-#{slug}", slug: slug) }

      allow(SecureRandom).to receive(:hex).with(Sluggable::TAIL_BYTES)
                                          .and_return("aaaa", "bbbb", "cccc")

      record = build_record(name: "Alex")
      record.save!

      expect(record.slug).to eq("alex-cccc")
    end

    it "does not count the current record as a collision when re-saving" do
      record = build_record(name: "Alex")
      record.save!
      expect { record.update!(updated_at: Time.current) }.not_to change(record, :slug)
    end
  end
end
