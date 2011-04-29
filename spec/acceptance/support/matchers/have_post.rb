Rspec::Matchers.define :have_post do |post|
  match do |page|
    page.html.should have_tag(".post", :id => "post-#{post.id}") do
      with_tag ".title", :text => post.title
      with_tag ".body",  :text => post.body
    end
  end
end
