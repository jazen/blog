require 'spec_helper'

describe Blog::Post do

  it { should be_mongoid_document }
  it { should be_timestamped_document }

  it { should have_field(:title).of_type(String) }
  it { should validate_presence_of(:title) }

  it "should be valid using the factory" do
    F.build("blog/post").should be_valid
  end

end
