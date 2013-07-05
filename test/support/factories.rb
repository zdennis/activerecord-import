Factory.sequence :book_title do |n|
  "Book #{n}" 
end

Factory.define :group do |m|
  m.sequence(:order) { |n| "Order #{n}" }
end

Factory.define :invalid_topic, :class => "Topic" do |m|
  m.sequence(:title){ |n| "Title #{n}"}
  m.author_name nil
end

Factory.define :topic do |m|
  m.sequence(:title){ |n| "Title #{n}"}
  m.sequence(:author_name){ |n| "Author #{n}"}
end

Factory.define :topic_with_book, :parent=>:topic do |m|
  m.after_build { |topic| 1.times {|y| topic.books.build(:title=>Factory.next(:book_title), :author_name=>'Stephen King') }}
end

Factory.define :widget do |m|
  m.sequence(:w_id){ |n| n}
end
