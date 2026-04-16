require "rails_helper"

RSpec.describe DatetimeFormatter do
  describe ".call" do
    let(:utc_time) { Time.utc(2026, 4, 15, 12, 30) }
    let(:date) { Date.new(2026, 4, 15) }

    def fmt(value, format: "european_24h", type: :datetime, zone: "UTC")
      Current.datetime_format = format
      Current.time_zone = zone
      described_class.call(value, type: type)
    ensure
      Current.reset
    end

    context "european_24h format" do
      it "formats datetime as dd.mm.yyyy HH:MM" do
        expect(fmt(utc_time, format: "european_24h")).to eq("15.04.2026 12:30")
      end

      it "formats date as dd.mm.yyyy" do
        expect(fmt(date, format: "european_24h", type: :date)).to eq("15.04.2026")
      end

      it "pads single-digit day and month" do
        expect(fmt(Time.utc(2026, 1, 3, 9, 5), format: "european_24h")).to eq("03.01.2026 09:05")
      end
    end

    context "iso format" do
      it "formats datetime as yyyy-mm-dd HH:MM" do
        expect(fmt(utc_time, format: "iso")).to eq("2026-04-15 12:30")
      end

      it "formats date as yyyy-mm-dd" do
        expect(fmt(date, format: "iso", type: :date)).to eq("2026-04-15")
      end
    end

    context "us_12h format" do
      it "formats afternoon datetime with single-digit hour, no leading zero" do
        expect(fmt(Time.utc(2026, 4, 15, 15, 30), format: "us_12h")).to eq("04/15/2026 3:30 PM")
      end

      it "formats date as mm/dd/yyyy" do
        expect(fmt(date, format: "us_12h", type: :date)).to eq("04/15/2026")
      end

      it "formats noon as 12:00 PM" do
        expect(fmt(Time.utc(2026, 4, 15, 12, 0), format: "us_12h")).to eq("04/15/2026 12:00 PM")
      end

      it "formats midnight as 12:00 AM" do
        expect(fmt(Time.utc(2026, 4, 15, 0, 0), format: "us_12h")).to eq("04/15/2026 12:00 AM")
      end

      it "formats morning hours without leading zero" do
        expect(fmt(Time.utc(2026, 4, 15, 9, 5), format: "us_12h")).to eq("04/15/2026 9:05 AM")
      end
    end

    context "time zone conversion" do
      it "converts datetime to Current.time_zone before formatting" do
        expect(fmt(utc_time, format: "european_24h", zone: "Europe/Moscow")).to eq("15.04.2026 15:30")
      end

      it "does not convert pure Date inputs (they have no zone)" do
        expect(fmt(date, format: "european_24h", type: :date, zone: "America/New_York")).to eq("15.04.2026")
      end

      it "handles ActiveSupport::TimeWithZone inputs" do
        twz = utc_time.in_time_zone("Europe/Moscow")
        expect(fmt(twz, format: "european_24h", zone: "Europe/Moscow")).to eq("15.04.2026 15:30")
      end

      it "shifts the date forward at the midnight boundary after zone conversion" do
        late_utc = Time.utc(2026, 4, 15, 23, 30)
        expect(fmt(late_utc, format: "european_24h", zone: "Europe/Moscow")).to eq("16.04.2026 02:30")
      end

      it "zone-converts a datetime even when rendering type :date" do
        late_utc = Time.utc(2026, 4, 15, 23, 30)
        expect(fmt(late_utc, format: "european_24h", type: :date, zone: "Europe/Moscow")).to eq("16.04.2026")
      end
    end

    context "nil input" do
      it "returns empty string for nil datetime" do
        expect(fmt(nil)).to eq("")
      end

      it "returns empty string for nil date" do
        expect(fmt(nil, type: :date)).to eq("")
      end
    end

    context "format fallback" do
      it "falls back to european_24h when Current.datetime_format is nil" do
        expect(fmt(utc_time, format: nil)).to eq("15.04.2026 12:30")
      end

      it "falls back to european_24h when Current.datetime_format is unknown" do
        expect(fmt(utc_time, format: "bogus")).to eq("15.04.2026 12:30")
      end
    end

    context "time zone fallback" do
      it "falls back to UTC when Current.time_zone is nil" do
        expect(fmt(utc_time, format: "european_24h", zone: nil)).to eq("15.04.2026 12:30")
      end

      it "falls back to UTC when Current.time_zone is blank" do
        expect(fmt(utc_time, format: "european_24h", zone: "")).to eq("15.04.2026 12:30")
      end

      it "falls back to UTC when Current.time_zone is not a valid IANA name" do
        expect(fmt(utc_time, format: "european_24h", zone: "Not/AZone")).to eq("15.04.2026 12:30")
      end
    end

    context "Date-typed input with :datetime type" do
      it "formats a Date passed to :datetime using the date-only portion of the format" do
        expect(fmt(date, format: "european_24h", type: :datetime)).to eq("15.04.2026 00:00")
      end
    end

    context "invalid type" do
      it "raises KeyError for an unknown type" do
        expect { fmt(utc_time, type: :unknown) }.to raise_error(KeyError)
      end
    end
  end
end
