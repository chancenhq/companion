[
  { country: "KE", name: "Chancen Kenya",        currency: "KES" },
  { country: "RW", name: "Chancen Rwanda",       currency: "RWF" },
  { country: "ZA", name: "Chancen South Africa", currency: "ZAR" },
  { country: "GH", name: "Chancen Ghana",        currency: "GHS" },
].each do |attrs|
  family = Family.find_or_initialize_by(name: attrs[:name])
  family.assign_attributes(country: attrs[:country], currency: attrs[:currency], locale: "en", country_hub: true)
  family.save!
end
