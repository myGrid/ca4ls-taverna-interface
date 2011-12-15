class CreateInputs < ActiveRecord::Migration
  def change
    create_table :inputs do |t|
      t.string   :name
      t.string   :value
      t.references :run
    end

    add_index :inputs, :run_id
  end
end
