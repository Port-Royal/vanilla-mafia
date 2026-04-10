require "rails_helper"

RSpec.describe PlayerNameRegex do
  describe ".build" do
    def match?(name, text)
      PlayerNameRegex.build(name).match?(text)
    end

    context "Cyrillic singular masculine consonant ending (Иван)" do
      it "matches nominative" do
        expect(match?("Иван", "Иван забил гол")).to be true
      end

      it "matches genitive Ивана" do
        expect(match?("Иван", "пас от Ивана был точным")).to be true
      end

      it "matches dative Ивану" do
        expect(match?("Иван", "передал Ивану мяч")).to be true
      end

      it "matches accusative Ивана" do
        expect(match?("Иван", "видел Ивана на поле")).to be true
      end

      it "matches instrumental Иваном" do
        expect(match?("Иван", "игра с Иваном")).to be true
      end

      it "matches prepositional Иване" do
        expect(match?("Иван", "говорили об Иване")).to be true
      end

      it "does not match a longer word starting with the name" do
        expect(match?("Иван", "Ивановка красивое место")).to be false
      end

      it "does not match when preceded by a Cyrillic letter" do
        expect(match?("Иван", "хИван")).to be false
      end
    end

    context "Cyrillic singular feminine -а ending (Маша)" do
      it "matches nominative" do
        expect(match?("Маша", "Маша играла хорошо")).to be true
      end

      it "matches genitive Маши" do
        expect(match?("Маша", "гол Маши был красивым")).to be true
      end

      it "matches dative Маше" do
        expect(match?("Маша", "пас Маше вышел удачным")).to be true
      end

      it "matches accusative Машу" do
        expect(match?("Маша", "видел Машу на поле")).to be true
      end

      it "matches instrumental Машей" do
        expect(match?("Маша", "с Машей в паре")).to be true
      end
    end

    context "Cyrillic multi-word feminine (Свирепая Кастрюля)" do
      it "matches nominative" do
        expect(match?("Свирепая Кастрюля", "Свирепая Кастрюля забила")).to be true
      end

      it "matches genitive" do
        expect(match?("Свирепая Кастрюля", "гол Свирепой Кастрюли")).to be true
      end

      it "matches dative" do
        expect(match?("Свирепая Кастрюля", "пас Свирепой Кастрюле")).to be true
      end

      it "matches accusative" do
        expect(match?("Свирепая Кастрюля", "встретил Свирепую Кастрюлю")).to be true
      end

      it "matches instrumental" do
        expect(match?("Свирепая Кастрюля", "играл со Свирепой Кастрюлей")).to be true
      end

      it "does not match across a different noun in between" do
        expect(match?("Свирепая Кастрюля", "Свирепая собака Кастрюля")).to be false
      end
    end

    context "Cyrillic plural-originated nickname (Грибочки)" do
      it "matches nominative plural" do
        expect(match?("Грибочки", "Грибочки выиграли матч")).to be true
      end

      it "matches genitive plural Грибочков" do
        expect(match?("Грибочки", "победа Грибочков была заслуженной")).to be true
      end

      it "matches dative plural Грибочкам" do
        expect(match?("Грибочки", "повезло Грибочкам сегодня")).to be true
      end

      it "matches instrumental plural Грибочками" do
        expect(match?("Грибочки", "играли с Грибочками в финале")).to be true
      end

      it "matches prepositional plural Грибочках" do
        expect(match?("Грибочки", "говорили о Грибочках вчера")).to be true
      end
    end

    context "Cyrillic plural-originated nickname (Вдохи)" do
      it "matches nominative plural" do
        expect(match?("Вдохи", "Вдохи вышли на поле")).to be true
      end

      it "matches genitive plural Вдохов" do
        expect(match?("Вдохи", "капитан Вдохов заявил")).to be true
      end

      it "matches instrumental plural Вдохами" do
        expect(match?("Вдохи", "сыграли с Вдохами")).to be true
      end
    end

    context "Latin names" do
      it "matches exact" do
        expect(match?("Alex", "Alex scored a goal")).to be true
      end

      it "does not match substring inside a longer word" do
        expect(match?("Alex", "Alexander scored")).to be false
      end

      it "does not add Cyrillic tail expansion to Latin names" do
        expect(match?("Alex", "Alexa")).to be false
      end
    end

    context "Cyrillic masculine adjective -ый/-ий (Хитрый)" do
      it "matches nominative" do
        expect(match?("Хитрый", "Хитрый забил гол")).to be true
      end

      it "matches genitive Хитрого (3-char ending)" do
        expect(match?("Хитрый", "пас Хитрого был точным")).to be true
      end

      it "matches instrumental Хитрым" do
        expect(match?("Хитрый", "играл с Хитрым")).to be true
      end

      it "does not match an unrelated word sharing the stem" do
        expect(match?("Хитрый", "Хитрости не помогли")).to be false
      end
    end

    context "Cyrillic neuter adjective -ое/-ее (Синее)" do
      it "matches nominative Синее" do
        expect(match?("Синее", "Синее играло хорошо")).to be true
      end

      it "matches genitive Синего" do
        expect(match?("Синее", "победа Синего была красивой")).to be true
      end
    end

    context "Cyrillic plural adjective -ые/-ие (Хитрые)" do
      it "matches nominative Хитрые" do
        expect(match?("Хитрые", "Хитрые выиграли")).to be true
      end

      it "matches genitive Хитрых" do
        expect(match?("Хитрые", "капитан Хитрых заявил")).to be true
      end

      it "matches instrumental Хитрыми" do
        expect(match?("Хитрые", "играли с Хитрыми")).to be true
      end
    end

    context "Cyrillic masculine -й (Алексей)" do
      it "matches nominative Алексей" do
        expect(match?("Алексей", "Алексей забил гол")).to be true
      end

      it "matches genitive Алексея" do
        expect(match?("Алексей", "пас Алексея был хорош")).to be true
      end

      it "matches instrumental Алексеем" do
        expect(match?("Алексей", "играл с Алексеем")).to be true
      end

      it "does not match a longer word sharing the stem" do
        expect(match?("Алексей", "Алексеевич сказал")).to be false
      end
    end

    context "Cyrillic singular feminine -я (Кастрюля)" do
      it "matches nominative Кастрюля" do
        expect(match?("Кастрюля", "Кастрюля играет")).to be true
      end

      it "matches accusative Кастрюлю" do
        expect(match?("Кастрюля", "встретил Кастрюлю")).to be true
      end

      it "matches instrumental Кастрюлей" do
        expect(match?("Кастрюля", "играл с Кастрюлей")).to be true
      end
    end

    context "Cyrillic neuter noun -о/-е (Море)" do
      it "matches nominative Море" do
        expect(match?("Море", "Море забило гол")).to be true
      end

      it "matches genitive Моря" do
        expect(match?("Море", "капитан Моря заявил")).to be true
      end

      it "matches instrumental Морем" do
        expect(match?("Море", "играл с Морем")).to be true
      end
    end

    context "very short Cyrillic name fallback" do
      it "treats a 2-char Cyrillic name as a literal" do
        expect(match?("Ян", "Ян забил")).to be true
      end

      it "does not declense a 2-char name" do
        expect(match?("Ян", "Яна забила")).to be false
      end
    end

    context "boundary and input handling" do
      it "declinses a 3-char Cyrillic name (boundary of stem fallback)" do
        expect(match?("Яна", "гол Яны был красивым")).to be true
      end

      it "strips surrounding whitespace from the input name" do
        expect(match?("  Иван  ", "Иван забил гол")).to be true
      end

      it "matches case-insensitively across the whole name" do
        expect(match?("Иван", "ИВАН забил гол")).to be true
      end

      it "does not let a Latin name attach to a following Cyrillic letter" do
        expect(match?("Alex", "Alex\u0430 scored")).to be false
      end

      it "treats multiple whitespace characters in the input name as a single separator" do
        expect(match?("Свирепая  Кастрюля", "Свирепая Кастрюля забила")).to be true
      end

      it "detects endings regardless of the input name's letter case" do
        expect(match?("МАША", "Маши гол был красивым")).to be true
      end
    end

    context "escaping regex metacharacters" do
      it "treats dots as literal" do
        expect(match?("A.B", "A.B scored")).to be true
      end

      it "does not let the dot match any character" do
        expect(match?("A.B", "AXB scored")).to be false
      end

      it "escapes metacharacters in a short Cyrillic name that bypasses stemming" do
        expect(match?("А.", "АЯ бежит")).to be false
      end
    end
  end
end
