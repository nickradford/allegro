class CreatePerformers < ActiveRecord::Migration
  def change
    create_table :performers do |t|
      t.string :name
      t.string :number
      t.binary :photo
      t.string :section

      t.timestamps
    end
  end
end
