class CreateWorkflows < ActiveRecord::Migration
  def change
    create_table :workflows do |t|
      t.string   :uuid
      t.string   :title
      t.string   :name
      t.text     :description
      t.string   :author
      t.text     :tag_list
      t.float    :version
      t.string   :licence_name
      t.text     :inputs_hash
      t.text     :outputs_hash
      t.text     :activities_hash
      t.string   :filename

      t.timestamps
    end
  end
end
