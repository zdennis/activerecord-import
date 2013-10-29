FactoryGirl.define do
  sequence(:book_title) {|n| "Book #{n}"}
  sequence(:chapter_title) {|n| "Chapter #{n}"}

  factory :group do
    sequence(:order) { |n| "Order #{n}" }
  end

  factory :invalid_topic, :class => "Topic" do
    sequence(:title){ |n| "Title #{n}"}
    author_name nil
  end

  factory :topic do
    sequence(:title){ |n| "Title #{n}"}
    sequence(:author_name){ |n| "Author #{n}"}
  end

  factory :widget do
    sequence(:w_id){ |n| n}
  end
  
  factory :topic_with_book, :parent=>:topic do |m|
    after(:build) do |topic| 
      2.times do 
        book = topic.books.build(:title=>FactoryGirl.generate(:book_title), :author_name=>'Stephen King') 
        3.times do
          book.chapters.build(:title => FactoryGirl.generate(:chapter_title))
        end
      end
    end
  end
end
