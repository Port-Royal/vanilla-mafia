# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Avo Russian translations" do
  around do |example|
    I18n.with_locale(:ru) { example.run }
  end

  it "translates core UI strings" do
    expect(I18n.t("avo.save")).to eq("Сохранить")
    expect(I18n.t("avo.edit")).to eq("редактировать")
    expect(I18n.t("avo.delete")).to eq("удалить")
    expect(I18n.t("avo.cancel")).to eq("Отмена")
  end

  it "translates search placeholder" do
    expect(I18n.t("avo.search.placeholder")).to eq("Поиск")
  end

  it "translates resource CRUD messages" do
    expect(I18n.t("avo.resource_created")).to eq("Запись создана")
    expect(I18n.t("avo.resource_updated")).to eq("Запись обновлена")
    expect(I18n.t("avo.resource_destroyed")).to eq("Запись удалена")
  end

  it "translates pagination" do
    expect(I18n.t("avo.per_page")).to eq("На странице")
    expect(I18n.t("avo.next_page")).to eq("Следующая страница")
    expect(I18n.t("avo.prev_page")).to eq("Предыдущая страница")
  end

  it "translates boolean values" do
    expect(I18n.t("avo.true")).to eq("Истина")
    expect(I18n.t("avo.false")).to eq("Ложь")
  end

  it "does not fall back to English for any avo key" do
    en_keys = I18n.t("avo", locale: :en).keys
    ru_keys = I18n.t("avo", locale: :ru).keys

    missing = en_keys - ru_keys

    expect(missing).to be_empty, "Missing Russian translations for avo keys: #{missing.join(', ')}"
  end
end
