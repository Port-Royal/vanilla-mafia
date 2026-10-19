# A lift ballot is now only «За»; a stored «Против» meant the same as not voting.
class DeleteAgainstLiftVotes < ActiveRecord::Migration[8.1]
  def up
    execute(delete_sql)
  end

  # The deleted ballots are not kept anywhere.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  # Only lift rounds: a candidate vote never carries for_lift, and a damaged one is not this migration's business.
  def delete_sql
    <<~SQL
      DELETE FROM breakdown_votes
      WHERE for_lift = #{connection.quoted_false}
        AND breakdown_vote_round_id IN (SELECT id FROM breakdown_vote_rounds WHERE kind = 'lift')
    SQL
  end
end
