require 'spec_helper'

describe Blog::Tag do

  it { should be_mongoid_document }
  it { should be_timestamped_document }

  it { should have_field(:name).of_type(String) }
  it { should validate_presence_of(:name) }

  it { should have_slug(:name) }

  it { should have_and_belong_to_many(:posts) }

  it "should be valid using the factory" do
    F.build("blog/tag").should be_valid
  end

end