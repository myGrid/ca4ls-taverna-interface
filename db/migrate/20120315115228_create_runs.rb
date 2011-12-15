class CreateRuns < ActiveRecord::Migration
  def self.up
    create_table :runs do |t|
      t.string   :instance
      t.boolean  :on_server
      t.string   :workflow
      t.string   :username
      t.string   :name
      t.text     :description
      t.datetime :createtime
      t.datetime :starttime
      t.datetime :finishtime
      t.string   :state
    end

    add_index :runs, :instance
  end

  def self.down
    drop_table :runs
  end
end
