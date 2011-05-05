Rspec::Matchers.define :have_post do |post|
  match do |page|
    page.html.should have_tag(".hentry.post", :id => "post-#{post.id}") do

      # The post's title
      with_tag ".entry-title" do
        with_tag "a[rel='bookmark'][title='#{post.title}']",
        :text => /#{post.title}/
      end

      # The publication date
      humanized_date = l(post.published_at, :format => :standard)
      with_tag ".entry-published", :text => /#{humanized_date}/

      # The post's author
      # TODO Remove rescue clause
      name = post.user.name rescue "Admin"
      with_tag ".entry-author", :text => /#{name}/

      # The post's content
      with_tag ".entry-content", :text => /#{post.body}/

      # The post's tags/categories
      with_tag ".entry-tags" do
        post.tags.each do |tag|
          with_tag "a[href$='#{tag.slug}']", :text => tag.name
        end
      end

    end
  end
end

Rspec::Matchers.define :have_link_to_post do |post|
  match do |page|
    path = helper.post_path(post)
    page.html.should have_tag "a[href$='#{path}']"
  end
end
