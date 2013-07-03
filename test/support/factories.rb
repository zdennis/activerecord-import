FactoryGirl.define do
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
end
