module Blog
  module PostsHelper

    def link_to_post(post, options = {})
      options.reverse_merge! \
      :backend => false

      backend = options.pluck(:backend)

      url = if backend
              blog.backend_post_path(post)

            else
              path_options = { :year => nil, :month => nil }

              if date = post.published_at
                path_options[:year]  = date.year.to_s
                path_options[:month] = date.month.to_s.rjust(2, "0")
              end

              blog.post_path(post, path_options)
            end

      options.reverse_merge! \
      :text  => post.title,
      :url   => url,
      :title => post.title

      text, url = options.pluck(:text, :url)

      link_to text, url, options
    end

    # Returns an <abbr>-markup'd date according to the hAtom spec.
    def pretty_date(date, options = {})
      options.reverse_merge! \
      :title  => date.iso8601,
      :format => :standard

      format = options.pluck(:format)

      content_tag :abbr, options do
        l(date, :format => format)
      end
    end

  end
end
