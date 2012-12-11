class CreateWorkers < ActiveRecord::Migration
  def change
    create_table :workers do |t|
      t.string   :image_id
      t.string   :name
      t.string   :instance_size
      t.integer  :tenancy_limit
      t.string   :taverna_path
      t.integer  :taverna_port
      t.string   :taverna_user
      t.string   :taverna_pass

      t.timestamps
    end

    add_column :workflows, :worker_id, :integer
    remove_column :runs, :on_server
  end
end
