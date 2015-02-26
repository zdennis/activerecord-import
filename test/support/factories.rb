FactoryGirl.define do
  factory :book do
    sequence(:title) { |n| "Title #{n}" }
    sequence(:publisher) { |n| "Publisher #{n}" }
    sequence(:author_name) { |n| "Author #{n}" }
  end

  factory :group do
    sequence(:order) { |n| "Order #{n}" }
  end

  factory :topic do
    sequence(:title) { |n| "Title #{n}" }
    sequence(:author_name) { |n| "Author #{n}" }
    factory :invalid_topic do
      author_name nil
    end
    factory :topic_with_books do
      books { build_list(:book, 3) }
    end
  end

  factory :widget do
    sequence(:w_id) { |n| n }
  end
end
