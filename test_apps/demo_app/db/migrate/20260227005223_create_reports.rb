class CreateReports < ActiveRecord::Migration[7.1]
  def change
    create_table :reports do |t|
      t.string :title
      t.string :category
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
