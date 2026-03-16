class AddCompetitionToNews < ActiveRecord::Migration[8.1]
  def change
    add_reference :news, :competition, null: true, foreign_key: true
  end
end
