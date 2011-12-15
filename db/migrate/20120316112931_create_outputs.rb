class CreateOutputs < ActiveRecord::Migration
  def change
    create_table :outputs do |t|
      t.string   :name
      t.string   :value
      t.references :run
    end

    add_index :outputs, :run_id
  end
end
