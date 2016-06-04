class CreateTableUser < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.integer :left, :right, :level
    end
    add_index :users, :left, unique: true
    add_index :users, :right, unique: true
    add_index :users, [:left, :right, :level]
  end
end
