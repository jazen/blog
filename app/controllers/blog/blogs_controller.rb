# -*- coding: utf-8 -*-
require "bson"

module Blog
  class BlogsController < SessionsController
    include Blog::UrlHelper

    layout :determine_layout

    respond_to :html, :except => %w(feed)
    respond_to :rss, :atom, :only => %w(feed)

    caches_page \
      :index,
      :slug,
      :archive,
      :posts_by_date,
      :posts_by_tag

    helper_method \
      :paginated?,
      :view_all?,
      :canonical_url

    before_filter \
      :redirect_slug_with_comma,
      :redirect_slug_with_post_id,
      :redirect_mixed_case_slug

    before_filter :set_noindex, only: %w(archive posts_by_date posts_by_tag)

    # TODO Should use paginated_posts and posts to avoid subtile errors..
    def index
      @posts = paginated(posts.latest(10))
      @page_title = t("blog.index.page_title")
      @meta_description = t("blog.index.page_title")
    end

    def feed
      @posts = paginated(posts.latest(10))
    end

    def slug
      slug   = params[:slug]
      @posts = posts.where(slug: /^#{slug}/)

      # Is there any post whose slug (or one of it's aliases) is an exact match?

      exact_match_post = posts.find_by_slug(slug)
      alias_match_post = posts.any_in(slug_aliases: [slug]).first

      # In case we found just one post and the slug's are not identical
      # this means it's a partial/broken slug and we should redirect
      # the user to the real url.

      if @posts.one? and !exact_match_post
        redirect_to public_post_path(@posts.first), status: :moved_permanently

      # Render a search results page if we found several posts whose
      # slugs start with the same given string. Tell search engines
      # not to index those pages.

      elsif @posts.many? and !exact_match_post and !alias_match_post
        @page_title       = t("blog.slug.search.page_title", query: slug)
        @meta_description = t("blog.slug.search.title", query: slug, count: @posts.size)
        @title            = t("blog.slug.search.title", query: slug)
        @noindex          = true
        @posts            = paginated(@posts)

      # We found an exact match and should show this post as expected.

      elsif @post = exact_match_post
        @page_title = t("blog.slug.post.page_title", title: @post.preferred_title)
        @meta_description = t("blog.slug.post.meta_description", description: @post.meta_description)
        @post.inc(:views, 1)

      # We found a post which got a matching slug alias.
      # Redirect to the current official slug.

      elsif alias_match_post
        redirect_to public_post_path(alias_match_post), status: :moved_permanently

      # Still got nothing? Let's see if there's a tag/category with a matching slug
      # and show all posts which belong to it.

      else
        @posts = posts.desc(:published_at).tagged_with(slug, slug: true)
        # TODO Ugly
        @tag = Blog::Tag.all.select { |t| t.slug == slug }.first

        if @posts.blank? or @tag.nil?
          render_404 and return
        end

        if view_all?
          @page_title = t("blog.slug.posts.page_title", title: @tag.name)
        else
          @page_title = t("blog.slug.posts.paginated_page_title", title: @tag.name, page: page)
          @posts = paginated(@posts)
        end

        @meta_description = t("blog.slug.posts.meta_description",
          title:       @tag.name,
          description: @posts.to_a.take(5).map(&:title).join(", ")
        )
      end
    end

    def archive
      @posts_by_year = Post.published.desc(:published_at).group_by do |post|
        post.published_at.year
      end

      @page_title = t("blog.archive.page_title")
      @meta_description = t("blog.archive.meta_description")
    end

    def posts_by_date
      year   = params[:year]
      month  = params[:month]
      @posts = posts.published(year, month)
      @date  = formatted_date(year, month)

      if view_all?
        @page_title = t("blog.posts_by_date.page_title", date: @date)
      else
        @page_title = t("blog.posts_by_date.paginated_page_title", date: @date, page: page)
        @posts = paginated(@posts)
      end

      @meta_description = t("blog.posts_by_date.meta_description", :description => enumerate_titles(@posts))
    end

    def posts_by_tag
      @posts = posts.desc(:published_at).tagged_with(params[:slug], :slug => true)
      # TODO Ugly
      @tag = Blog::Tag.all.select { |t| t.slug == params[:slug] }.first

      if view_all?
        @page_title = t("blog.posts_by_tag.page_title", title: @tag.name)
      else
        @page_title = t("blog.posts_by_tag.paginated_page_title", title: @tag.name, page: page)
        @posts = paginated(@posts)
      end

      @meta_description = t("blog.posts_by_tag.meta_description", :description => enumerate_titles(@posts))
    end

    # Some websites are pretty stupid and shorten links randomly (adding ".." to the end).
    # Lets try to fix this shit by removing the broken stuff and looking for a post whose
    # slug's beginning matches.
    #
    # Example: /a-fresh-new-po.. should redirect to the post with slug /a-fresh-new-post
    #
    # NOTE:
    # An URL like this generates an ActionController::RoutingError so we have to handle it
    # with a catch-all route at the bottom of config/routes.rb

    def routing_error
      broken_pattern = /\.{1,3}$/

      if params[:shit] =~ broken_pattern
        partial_slug = params[:shit].split("/").last.gsub(broken_pattern, '')
        if post = posts.where(slug: /^#{partial_slug}/).first
          redirect_to public_post_path(post), status: :moved_permanently and return
        end
      end

      render_404
    end

    private # ----------------------------------------------

    # TODO This belongs into a decorator?
    def set_noindex
      @noindex = true
    end

    def render_404
      @page_title = t("blog.errors.not_found.page_title")
      render "errors/404-not-found", status: :not_found
    end

    # There was a time when commata where not removed from a post's slug. Even months
    # after this issue was fixed GoogleBot is still trying to access them which leads
    # to crawl errors in Google Webmasters Tools.

    def redirect_slug_with_comma
      if params[:slug] =~ /,/
        redirect_to request.fullpath.gsub(',', ''), status: :moved_permanently
      end
    end

    # No idea where Google got them from but the bot is trying to access posts using
    # their internal IDs. This is annoying.

    def redirect_slug_with_post_id
      if BSON::ObjectId.legal?(params[:slug]) and post = posts.find(params[:slug])
        redirect_to public_post_path(post), status: :moved_permanently
      end
    end

    # Ensure we always using lowercased slugs.
    # Some people linking manually will mix it up for sure.

    def redirect_mixed_case_slug
      if params[:slug] =~ /[A-Z]/
        redirect_to request.fullpath.downcase, status: :moved_permanently
      end
    end

    def enumerate_titles(posts, limit = 5)
      posts.to_a.take(limit).map { |post|
        '"' + post.title + '"'
      }.join(", ") + ", ..."
    end

    def determine_layout(default = "application")
      Settings.blog.layout || default
    rescue
      default
    end

    def canonical_url
      proto = request.scheme + "://"
      path  = request.fullpath.split("/page/").first
      host  = request.host_with_port
      url   = proto + host + path

      if paginated? or view_all? or @tag
        url << "/page/all"
      end

      url
    end

    def page
      (params[:page] || 1).to_i
    end

    def paginated?
      params.include?(:page)
    end

    def view_all?
      params[:page] == "all"
    end

    def posts
      Post.published
    end

    def paginated(posts)
      view_all? ? posts : posts.page(params[:page])
    end

    def formatted_date(year, month)
      if month.blank?
        date = Time.parse("#{year}/01")
        l(date, :format => "%Y")
      else
        month = month.to_s.rjust(2, "0")
        date  = Time.parse("#{year}/#{month}")
        l(date, :format => "%B %Y")
      end
    end

  end
end
