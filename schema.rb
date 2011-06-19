require 'sequel'

DB = Sequel::Database.connect(ENV["DATABASE_URL"] || "sqlite://db.db")

DB.create_table? :pages do
  Integer :id, :primary_key => true
  DateTime :created_on
  String :name
  String :description
end

DB.create_table? :update do
  DateTime :updated_at
end
