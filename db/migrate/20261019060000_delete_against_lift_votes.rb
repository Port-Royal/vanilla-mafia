# A lift ballot is now only «За»; a stored «Против» meant the same as not voting.
class DeleteAgainstLiftVotes < ActiveRecord::Migration[8.1]
  def up
    execute(delete_sql)
  end

  # The deleted ballots are not kept anywhere.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def delete_sql
    "DELETE FROM breakdown_votes WHERE for_lift = #{connection.quoted_false}"
  end
end
