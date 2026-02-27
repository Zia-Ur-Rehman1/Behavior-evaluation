puts "Seeding..."

# Users
admin = User.create!(name: "Admin User", email: "admin@example.com", password: "password123", role: :admin)
editor = User.create!(name: "Editor User", email: "editor@example.com", password: "password123", role: :editor)
viewer = User.create!(name: "Viewer User", email: "viewer@example.com", password: "password123", role: :viewer)

# Products
5.times do |i|
  Product.create!(name: "Product #{i+1}", price: (10 + i * 5.5).round(2), description: "Description for product #{i+1}")
end

# Articles
3.times do |i|
  Article.create!(title: "Article #{i+1}", body: "Body content for article #{i+1}. " * 5, published: i.even?)
end

# Reports
4.times do |i|
  Report.create!(title: "Report #{i+1}", category: ["Sales", "Marketing", "Engineering", "Support"][i], status: ["open", "in_progress", "closed", "open"][i], notes: "Notes for report #{i+1}")
end

puts "Done! Created #{User.count} users, #{Product.count} products, #{Article.count} articles, #{Report.count} reports"
puts "Login credentials:"
puts "  Admin:  admin@example.com / password123"
puts "  Editor: editor@example.com / password123"
puts "  Viewer: viewer@example.com / password123"
