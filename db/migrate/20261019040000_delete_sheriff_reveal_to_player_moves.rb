# The sheriff_reveal_to_player kind is gone from the move catalogue; a row of it would fail the kind validation.
class DeleteSheriffRevealToPlayerMoves < ActiveRecord::Migration[8.1]
  def up
    execute(delete_sql)
  end

  # The deleted moves are not kept anywhere.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def delete_sql
    "DELETE FROM breakdown_moves WHERE kind = 'sheriff_reveal_to_player'"
  end
end
