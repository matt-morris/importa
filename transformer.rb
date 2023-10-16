require_relative "lib/importa"

class Transformer < Importa::BaseTransformer
  field :first_name
  field :last_name
  field :dob, :date
  field :member_id
  field :effective_date, :date
  field :expiry_date, :date, optional: true
  field :phone_number, :phone, optional: true
end
