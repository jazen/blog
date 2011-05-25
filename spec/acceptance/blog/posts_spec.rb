require 'acceptance/acceptance_helper'

feature "Posts", %q{
  In order to have an awesome blog
  As an author
  I want to create and manage posts
} do

  background do
    @one = F("blog/post", :title => "One", :body => "This is a body")
    @two = F("blog/post", :title => "Two", :body => "Second body")

    # FIXME Add real users/accounts
    basic_auth "baktinet", "6bd5069e47fc68f2"
  end

  scenario "Posts index" do # --------------------------------------------------
    visit '/blog/backend/posts'

    page.html.should have_tag ".post" do
      with_tag ".title", :text => "One"
      with_tag ".body", :text => "This is a body"
    end
  end

  scenario "Create post" do # --------------------------------------------------
    visit "/blog/backend/posts"
    click_on t("backend.actions.create_post")

    within "form#new_blog_post" do
      fill_in "post_title", :with => "A new post"
      fill_in "post_body",  :with => "The real content"

      find("*[type='submit']").click
    end

    page.should have_content t("post.created")
  end

  scenario "Update post" do # --------------------------------------------------
    visit "/blog/backend/posts"

    within ".posts li:first-child" do
      click_on t("backend.post_actions.edit")
    end

    within "form[id^='edit_blog_post']" do
      fill_in "post_body", :with => "Updated content"

      find("*[type='submit']").click
    end

    page.should have_content t("post.updated")
  end

  scenario "View public post" do # ---------------------------------------------
    post = F("blog/post",
             :title => "A post",
             :body => "The content.",
             :page_title => "",
             :meta_description => "",
             :published_at => 1.day.ago)

    visit public_post_path(post)

    page.html.should have_tag "title", :text => "A post"
    page.html.should_not have_tag "meta[name='description']"

    page.html.should have_tag ".post" do
      with_tag ".entry-title", :text => "A post"
      with_tag ".entry-content", :text => /The content/
    end
  end

  scenario "Adding tags to a post" do # ----------------------------------------
    post = F("blog/post", :title => "A post", :published_at => 1.day.ago)

    visit edit_backend_post_path(post)

    within "form[id^='edit_blog_post']" do
      fill_in "post_tag_list", :with => "General, Updates"
      find("*[type='submit']").click
    end

    visit public_post_path(post)

    page.html.should have_tag ".post .tags" do
      with_tag "a", :text => /General/
      with_tag "a", :text => /Updates/
    end
  end

  scenario "Add custom page title" do # ----------------------------------------
    post = F("blog/post", :title => "A post", :published_at => 1.day.ago)

    visit edit_backend_post_path(post)

    within "form[id^='edit_blog_post']" do
      fill_in "post_page_title", :with => "Custom page title"
      find("*[type='submit']").click
    end

    visit public_post_path(post)

    page.html.should have_tag "title", :text => "Custom page title"
  end

  scenario "Add custom meta description" do # ----------------------------------
    post = F("blog/post", :title => "A post", :published_at => 1.day.ago)

    visit edit_backend_post_path(post)

    within "form[id^='edit_blog_post']" do
      fill_in "post_meta_description", :with => "Custom meta description"
      find("*[type='submit']").click
    end

    visit public_post_path(post)

    page.html.should have_tag "meta[name='description'][content='Custom meta description']"
  end

  # FIXME
  # have_tag can't handle the colon in the custom tag's name...
  #
  # scenario "Use meta description for addthis button" do # ----------------------
  #   post = F("blog/post",
  #            :title => "A post",
  #            :meta_description => "A custom description",
  #            :published_at => 1.day.ago)

  #   visit public_post_path(post)

  #   page.html.should have_tag ".addthis_toolbox[addthis:description='A custom description']"
  # end

end
