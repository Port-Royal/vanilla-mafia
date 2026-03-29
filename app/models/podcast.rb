class Podcast < ApplicationRecord
  has_one_attached :cover

  validates :title, presence: true
  validates :author, presence: true
  validates :description, presence: true
  validates :language, presence: true

  def self.instance
    first || create!(
      title: "Vanilla Mafia",
      author: "Vanilla Mafia",
      description: "Подкаст клуба спортивной мафии Vanilla Mafia",
      language: "ru"
    )
  end
end
