class CreateGameBreakdowns < ActiveRecord::Migration[8.1]
  def change
    create_table :game_breakdowns do |t|
      t.string :title, null: false
      t.date :played_on
      t.string :source
      t.string :video_url
      t.string :judge_name
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :roles_mode, null: false, default: "open"
      t.references :game, foreign_key: true
      t.string :manual_result
      t.text :conclusion

      t.timestamps
    end

    create_table :breakdown_seats do |t|
      t.references :game_breakdown, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :name
      t.references :player, foreign_key: true
      t.string :role_code

      t.timestamps
    end

    add_index :breakdown_seats, [ :game_breakdown_id, :number ], unique: true
    add_index :breakdown_seats, :role_code
    add_foreign_key :breakdown_seats, :roles, column: :role_code, primary_key: :code

    create_table :breakdown_phases do |t|
      t.references :game_breakdown, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :night_outcome
      t.integer :killed_seat

      t.timestamps
    end

    add_index :breakdown_phases, [ :game_breakdown_id, :position ], unique: true

    create_table :breakdown_night_actions do |t|
      t.references :breakdown_phase, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :actor_seat
      t.integer :target_seat

      t.timestamps
    end

    create_table :breakdown_vote_rounds do |t|
      t.references :breakdown_phase, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :kind, null: false

      t.timestamps
    end

    add_index :breakdown_vote_rounds, [ :breakdown_phase_id, :number ], unique: true

    create_table :breakdown_speeches do |t|
      t.references :breakdown_phase, null: false, foreign_key: true
      t.integer :speaker_seat, null: false
      t.string :kind, null: false
      t.integer :position, null: false
      t.references :breakdown_vote_round, foreign_key: true

      t.timestamps
    end

    create_table :breakdown_votes do |t|
      t.references :breakdown_vote_round, null: false, foreign_key: true
      t.integer :voter_seat, null: false
      t.integer :candidate_seat
      t.boolean :for_lift

      t.timestamps
    end

    add_index :breakdown_votes, [ :breakdown_vote_round_id, :voter_seat ], unique: true,
                                                                            name: "index_breakdown_votes_on_round_and_voter_seat"

    create_table :breakdown_moves do |t|
      t.references :breakdown_speech, foreign_key: true
      t.references :breakdown_vote_round, foreign_key: true
      t.integer :position, null: false
      t.string :kind, null: false
      t.integer :actor_seat, null: false
      t.integer :target_seat
      t.string :claimed_color
      t.integer :night_number
      t.json :best_move_seats
      t.string :removal_reason
      t.text :text

      t.timestamps

      t.check_constraint "(breakdown_speech_id IS NULL) <> (breakdown_vote_round_id IS NULL)",
                         name: "breakdown_moves_exactly_one_context"
    end
  end
end
