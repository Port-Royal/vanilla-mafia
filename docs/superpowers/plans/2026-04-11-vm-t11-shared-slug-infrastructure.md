# vm-t11 (gh-768) Shared Slug Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the shared `CyrillicTransliterator` PORO and `Sluggable` concern that vm-50..vm-54 will use to add slug-based public URLs.

**Architecture:** Two standalone, fully-unit-tested building blocks with no model integration. `CyrillicTransliterator` is a pure function over strings. `Sluggable` is an ActiveSupport::Concern that adds slug generation, `to_param`, and validations to any model declaring `slug_source :attr`. Extensible via an `if:` option and via overriding the private `slug_base` method.

**Tech Stack:** Ruby 4.0.1, Rails 8.1.2, RSpec with `let_it_be`/`let`, evilution + mutant for mutation testing.

**Reference spec:** `docs/superpowers/specs/2026-04-11-public-url-slugs-design.md`

---

## File Structure

- Create: `app/services/cyrillic_transliterator.rb` — PORO, one class method `.call(string)`
- Create: `app/models/concerns/sluggable.rb` — ActiveSupport::Concern
- Create: `spec/services/cyrillic_transliterator_spec.rb` — unit tests
- Create: `spec/models/concerns/sluggable_spec.rb` — unit tests using an anonymous AR model

---

## Task 1: CyrillicTransliterator — failing test

**Files:**
- Test: `spec/services/cyrillic_transliterator_spec.rb`

- [ ] **Step 1: Write the failing test file**

```ruby
require "rails_helper"

RSpec.describe CyrillicTransliterator do
  describe ".call" do
    def tr(input)
      described_class.call(input)
    end

    context "lowercase letters" do
      it "transliterates simple letters" do
        expect(tr("абвгд")).to eq("abvgd")
      end

      it "transliterates е and ё" do
        expect(tr("ежё")).to eq("ezhyo")
      end

      it "transliterates ж, з, и, й" do
        expect(tr("жзий")).to eq("zhziy")
      end

      it "transliterates к, л, м, н, о, п" do
        expect(tr("клмноп")).to eq("klmnop")
      end

      it "transliterates р, с, т, у, ф" do
        expect(tr("рстуф")).to eq("rstuf")
      end

      it "transliterates multi-char mappings х, ц, ч, ш, щ" do
        expect(tr("хцчшщ")).to eq("khtschshshch")
      end

      it "erases hard sign ъ and soft sign ь" do
        expect(tr("ъь")).to eq("")
      end

      it "transliterates ы, э, ю, я" do
        expect(tr("ыэюя")).to eq("yeyuya")
      end
    end

    context "uppercase letters" do
      it "transliterates uppercase letters to lowercase latin" do
        expect(tr("ИВАН")).to eq("ivan")
      end

      it "transliterates mixed case" do
        expect(tr("Иван")).to eq("ivan")
      end

      it "transliterates uppercase multi-char mappings" do
        expect(tr("ЩЁ")).to eq("shchyo")
      end
    end

    context "non-Cyrillic passthrough" do
      it "passes Latin letters through unchanged" do
        expect(tr("hello")).to eq("hello")
      end

      it "passes digits through unchanged" do
        expect(tr("12345")).to eq("12345")
      end

      it "passes punctuation through unchanged" do
        expect(tr("a-b_c.d")).to eq("a-b_c.d")
      end

      it "passes whitespace through unchanged" do
        expect(tr("a b c")).to eq("a b c")
      end
    end

    context "mixed input" do
      it "handles Cyrillic and Latin together" do
        expect(tr("Kirill Х")).to eq("kirill kh")
      end

      it "handles Cyrillic with digits" do
        expect(tr("Игрок42")).to eq("igrok42")
      end

      it "handles multi-word Cyrillic with spaces" do
        expect(tr("Иван Петров")).to eq("ivan petrov")
      end
    end

    context "edge cases" do
      it "returns an empty string for empty input" do
        expect(tr("")).to eq("")
      end

      it "handles nil by treating it as empty string" do
        expect(tr(nil)).to eq("")
      end

      it "returns whitespace unchanged" do
        expect(tr("   ")).to eq("   ")
      end
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/services/cyrillic_transliterator_spec.rb`
Expected: FAIL with `NameError: uninitialized constant CyrillicTransliterator`

---

## Task 2: CyrillicTransliterator — implementation

**Files:**
- Create: `app/services/cyrillic_transliterator.rb`

- [ ] **Step 1: Write the implementation**

```ruby
class CyrillicTransliterator
  TABLE = {
    "а" => "a", "б" => "b", "в" => "v", "г" => "g", "д" => "d",
    "е" => "e", "ё" => "yo", "ж" => "zh", "з" => "z", "и" => "i",
    "й" => "y", "к" => "k", "л" => "l", "м" => "m", "н" => "n",
    "о" => "o", "п" => "p", "р" => "r", "с" => "s", "т" => "t",
    "у" => "u", "ф" => "f", "х" => "kh", "ц" => "ts", "ч" => "ch",
    "ш" => "sh", "щ" => "shch", "ъ" => "", "ы" => "y", "ь" => "",
    "э" => "e", "ю" => "yu", "я" => "ya"
  }.freeze

  def self.call(string)
    string.to_s.each_char.map { |char| TABLE[char.downcase] || char }.join
  end
end
```

- [ ] **Step 2: Run the tests to verify they pass**

Run: `bundle exec rspec spec/services/cyrillic_transliterator_spec.rb`
Expected: All examples pass

- [ ] **Step 3: Run rubocop on the new files**

Run: `bundle exec rubocop app/services/cyrillic_transliterator.rb spec/services/cyrillic_transliterator_spec.rb`
Expected: no offences

- [ ] **Step 4: Commit**

```bash
git add app/services/cyrillic_transliterator.rb spec/services/cyrillic_transliterator_spec.rb
git commit -m "vm-t11: add CyrillicTransliterator PORO"
```

---

## Task 3: Sluggable concern — failing test (basic generation)

**Files:**
- Test: `spec/models/concerns/sluggable_spec.rb`

- [ ] **Step 1: Write the initial spec file with an anonymous test model**

```ruby
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

    stub_const("SluggableTestRecord", Class.new(ApplicationRecord) {
      self.table_name = "sluggable_test_records"
      include Sluggable
      slug_source :name
    })
  end

  after(:all) do
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
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/models/concerns/sluggable_spec.rb`
Expected: FAIL with `NameError: uninitialized constant Sluggable`

---

## Task 4: Sluggable concern — initial implementation

**Files:**
- Create: `app/models/concerns/sluggable.rb`

- [ ] **Step 1: Write the concern**

```ruby
module Sluggable
  extend ActiveSupport::Concern

  TAIL_BYTES = 2 # => 4 hex characters

  class_methods do
    attr_reader :slug_source_attribute, :slug_source_condition

    def slug_source(attribute, if: nil)
      @slug_source_attribute = attribute
      @slug_source_condition = binding.local_variable_get(:if)
    end
  end

  included do
    validates :slug, presence: true, uniqueness: true
    before_validation :generate_slug, if: :should_generate_slug?
  end

  def to_param
    slug
  end

  private

  def should_generate_slug?
    return false if slug.present?

    condition = self.class.slug_source_condition
    condition.nil? || instance_exec(&condition)
  end

  def generate_slug
    base = slug_base
    candidate = base
    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{SecureRandom.hex(Sluggable::TAIL_BYTES)}"
    end
    self.slug = candidate
  end

  def slug_base
    raw = public_send(self.class.slug_source_attribute).to_s
    CyrillicTransliterator.call(raw).parameterize.presence ||
      SecureRandom.hex(Sluggable::TAIL_BYTES)
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `bundle exec rspec spec/models/concerns/sluggable_spec.rb`
Expected: all examples pass

- [ ] **Step 3: Commit**

```bash
git add app/models/concerns/sluggable.rb spec/models/concerns/sluggable_spec.rb
git commit -m "vm-t11: add Sluggable concern with basic generation"
```

---

## Task 5: Sluggable — collision handling tests + verification

**Files:**
- Test: `spec/models/concerns/sluggable_spec.rb`

- [ ] **Step 1: Add collision-handling examples**

Append to the existing `RSpec.describe Sluggable do` block, before the final `end`:

```ruby
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
```

- [ ] **Step 2: Run the tests**

Run: `bundle exec rspec spec/models/concerns/sluggable_spec.rb`
Expected: all examples pass

- [ ] **Step 3: Commit**

```bash
git add spec/models/concerns/sluggable_spec.rb
git commit -m "vm-t11: Sluggable collision-handling tests"
```

---

## Task 6: Sluggable — blank/fallback and validation tests

**Files:**
- Test: `spec/models/concerns/sluggable_spec.rb`

- [ ] **Step 1: Add fallback/validation examples**

Append to the `RSpec.describe Sluggable do` block:

```ruby
describe "fallback when source is blank after transliteration" do
  it "generates a random hex slug when the source attribute is empty" do
    record = build_record(name: "")
    record.save!
    expect(record.slug).to match(/\A[0-9a-f]{4}\z/)
  end

  it "generates a random hex slug when the source yields an empty parameterize result" do
    # Soft sign alone transliterates to the empty string
    record = build_record(name: "ь")
    record.save!
    expect(record.slug).to match(/\A[0-9a-f]{4}\z/)
  end
end

describe "validations" do
  it "is valid when a slug is present" do
    record = build_record(name: "Alex")
    expect(record).to be_valid
  end

  it "rejects two records that somehow end up with the same slug" do
    SluggableTestRecord.create!(name: "Alex")
    duplicate = SluggableTestRecord.new(name: "seed", slug: "alex")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:slug]).to include(/taken/i)
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `bundle exec rspec spec/models/concerns/sluggable_spec.rb`
Expected: all examples pass

- [ ] **Step 3: Commit**

```bash
git add spec/models/concerns/sluggable_spec.rb
git commit -m "vm-t11: Sluggable fallback and validation tests"
```

---

## Task 7: Sluggable — conditional generation tests

**Files:**
- Test: `spec/models/concerns/sluggable_spec.rb`

- [ ] **Step 1: Add a second anonymous model with an `if:` condition and tests**

Inside the existing `RSpec.describe Sluggable do` block, **below** the existing `before(:all)` block, add:

```ruby
before(:all) do
  ActiveRecord::Base.connection.create_table(:sluggable_conditional_records, force: true) do |t|
    t.string :name
    t.string :slug
    t.boolean :ready, default: false
    t.timestamps
  end

  stub_const("SluggableConditionalRecord", Class.new(ApplicationRecord) {
    self.table_name = "sluggable_conditional_records"
    include Sluggable
    slug_source :name, if: -> { ready? }
  })
end

after(:all) do
  ActiveRecord::Base.connection.drop_table(:sluggable_conditional_records)
end
```

Then add a `describe` block:

```ruby
describe "conditional generation via :if option" do
  it "skips slug generation when the condition returns false" do
    record = SluggableConditionalRecord.new(name: "Alex", ready: false)
    record.valid?
    expect(record.slug).to be_blank
  end

  it "generates the slug when the condition returns true" do
    record = SluggableConditionalRecord.new(name: "Alex", ready: true)
    record.valid?
    expect(record.slug).to eq("alex")
  end

  it "does not overwrite an existing slug even after the condition flips" do
    record = SluggableConditionalRecord.new(name: "Alex", ready: true)
    record.save!
    original = record.slug

    record.update_columns(name: "Bob")
    record.valid?
    expect(record.slug).to eq(original)
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `bundle exec rspec spec/models/concerns/sluggable_spec.rb`
Expected: all examples pass

- [ ] **Step 3: Commit**

```bash
git add spec/models/concerns/sluggable_spec.rb
git commit -m "vm-t11: Sluggable conditional generation tests"
```

---

## Task 8: Sluggable — `slug_base` override extensibility test

**Files:**
- Test: `spec/models/concerns/sluggable_spec.rb`

- [ ] **Step 1: Add an anonymous model that overrides `slug_base` and tests it**

In the spec, add another `before(:all)` block at the top (each `before(:all)` accumulates, so this is additive):

```ruby
before(:all) do
  ActiveRecord::Base.connection.create_table(:sluggable_prefixed_records, force: true) do |t|
    t.string :title
    t.string :slug
    t.date :publish_date
    t.timestamps
  end

  stub_const("SluggablePrefixedRecord", Class.new(ApplicationRecord) {
    self.table_name = "sluggable_prefixed_records"
    include Sluggable
    slug_source :title

    private

    def slug_base
      "#{publish_date.iso8601}-#{CyrillicTransliterator.call(title.to_s).parameterize}"
    end
  })
end

after(:all) do
  ActiveRecord::Base.connection.drop_table(:sluggable_prefixed_records)
end
```

Then the test:

```ruby
describe "subclass overriding slug_base" do
  it "uses the overridden base for slug generation" do
    record = SluggablePrefixedRecord.new(title: "Голевой пас", publish_date: Date.new(2026, 4, 11))
    record.save!
    expect(record.slug).to eq("2026-04-11-golevoy-pas")
  end

  it "still applies collision handling to the overridden base" do
    SluggablePrefixedRecord.create!(title: "Pas", publish_date: Date.new(2026, 4, 11))
    second = SluggablePrefixedRecord.new(title: "Pas", publish_date: Date.new(2026, 4, 11))
    second.save!
    expect(second.slug).to match(/\A2026-04-11-pas-[0-9a-f]{4}\z/)
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `bundle exec rspec spec/models/concerns/sluggable_spec.rb`
Expected: all examples pass

- [ ] **Step 3: Run rubocop**

Run: `bundle exec rubocop app/models/concerns/sluggable.rb spec/models/concerns/sluggable_spec.rb`
Expected: no offences. Fix any style issues before committing.

- [ ] **Step 4: Commit**

```bash
git add spec/models/concerns/sluggable_spec.rb
git commit -m "vm-t11: Sluggable slug_base override extensibility test"
```

---

## Task 9: Full test suite run

- [ ] **Step 1: Run the full RSpec suite to catch any regressions**

Run: `bundle exec rspec`
Expected: all examples pass. If any pre-existing test breaks, investigate before proceeding — the new concern and PORO do not touch any model, so failures should not be caused by this work.

- [ ] **Step 2: Run rubocop on the full diff**

Run: `bundle exec rubocop $(git diff --name-only master -- '*.rb')`
Expected: no offences.

---

## Task 10: Mutation testing with evilution

- [ ] **Step 1: Run evilution on CyrillicTransliterator**

Run: `bundle exec evilution run app/services/cyrillic_transliterator.rb -j 4`
Expected: score >= 90%. If surviving mutants exist, add targeted tests for each survivor until they are killed. Common survivors on lookup-table code: boundary cases (`downcase` removal, `||` flip to `&&`, `each_char` to `chars`). Address each before continuing.

- [ ] **Step 2: Run evilution on Sluggable**

Run: `bundle exec evilution run app/models/concerns/sluggable.rb -j 4`
Expected: score >= 90%. Likely survivors on this file: tail-length constant, the `while` loop condition, the `.presence` fallback. Add targeted tests for each survivor until they are killed.

- [ ] **Step 3: Append evilution feedback to the local log**

Run: open `.artifacts.local/regular-evilution-feedback.log` and append an entry with the evilution version (`bundle exec evilution --version`), the files tested, final scores, any surviving mutants, and observations about evilution's behaviour on this code.

---

## Task 11: Mutation testing with mutant

- [ ] **Step 1: Run mutant on CyrillicTransliterator**

Run: `bundle exec mutant run --jobs 1 -- 'CyrillicTransliterator*'`
Expected: no surviving mutants on `CyrillicTransliterator.call`. If any survive, add targeted tests.

- [ ] **Step 2: Run mutant on Sluggable**

Run: `bundle exec mutant run --jobs 1 -- 'Sluggable*'`
Expected: no surviving mutants on Sluggable method bodies. Mutant only mutates `def` method bodies, so the class-level `validates`/`before_validation` DSL is not covered — those are already validated by the RSpec suite. If mutant survivors appear in `generate_slug`, `slug_base`, `should_generate_slug?`, or `to_param`, add targeted tests.

- [ ] **Step 3: Append mutant feedback to the local log**

Append a second entry comparing mutant and evilution findings: what mutant caught that evilution missed, and vice versa.

---

## Task 12: Final commit and PR

- [ ] **Step 1: Check git status**

Run: `git status`
Expected: clean working tree or only the `.artifacts.local/regular-evilution-feedback.log` file modified.

- [ ] **Step 2: If tests were added during mutation testing, commit them**

```bash
git add spec/services/cyrillic_transliterator_spec.rb spec/models/concerns/sluggable_spec.rb
git commit -m "vm-t11: kill surviving mutants in CyrillicTransliterator and Sluggable"
```

(Skip this step if no new tests were needed.)

- [ ] **Step 3: Push the branch**

Run: `git push -u origin vanilla-mafia-768`
Expected: branch pushed.

- [ ] **Step 4: Open the PR**

Run:

```bash
gh pr create --title "vm-t11: add shared slug infrastructure (CyrillicTransliterator + Sluggable concern)" --body "$(cat <<'EOF'
## Summary
- Adds `CyrillicTransliterator` PORO (`app/services/cyrillic_transliterator.rb`) with a lookup table covering all 33 Russian letters.
- Adds `Sluggable` concern (`app/models/concerns/sluggable.rb`) providing slug generation, `to_param`, uniqueness validation, and collision handling via a hex tail. Extensible via an `if:` option and via overriding `slug_base`.
- No model integrations yet — vm-50..vm-54 will apply this infrastructure per-entity.

## Mutation testing
- Evilution: X% (Y/Z mutants killed)
- Mutant: X% (Y/Z mutants killed)

## Test plan
- [x] `bundle exec rspec spec/services/cyrillic_transliterator_spec.rb`
- [x] `bundle exec rspec spec/models/concerns/sluggable_spec.rb`
- [x] `bundle exec rspec` (full suite, no regressions)
- [x] `bundle exec rubocop` on changed files
- [x] Evilution and mutant runs against both new files

Closes #768

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: Assign marinazzio on the PR**

Run: `gh api repos/Port-Royal/vanilla-mafia/issues/$(gh pr view --json number -q .number) --method PATCH -f "assignees[]=marinazzio"`
Expected: PR assigned.

- [ ] **Step 6: Return PR URL**

Run: `gh pr view --json url -q .url`
Output the URL so the user can review.
