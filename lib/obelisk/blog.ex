defmodule Obelisk.Blog do
  require Integer

  defp get_sort_order do
    Obelisk.Config.config[:sort_posts]
  end

  defp sort_by_created(:ascending) do
    &(&1.frontmatter.created <= &2.frontmatter.created)
  end
  defp sort_by_created(:descending) do
    &(&1.frontmatter.created >= &2.frontmatter.created)
  end

  defp get_sort_function do
    case get_sort_order do
      "descending" ->
        sort_by_created :descending

      "ascending" ->
        sort_by_created :ascending

      _ ->
        sort_by_created :ascending
    end
  end

  defmodule IndexPage do
    defstruct(
      next_page: nil,
      previous_page: nil,
      content: nil,
      document: nil
    )
  end

  def compile_index(posts, store) do
    make_path get_blog_index

    layouts = Obelisk.Store.get_layouts store

    posts
    |> Enum.sort(get_sort_function)
    |> _compile_index(layouts, get_posts_per_page, 1)
  end

  defp _compile_index([], _, _, _), do: nil
  defp _compile_index(posts, layouts, posts_per_page, page_number) do
    path = html_filename page_number

    { current, remaining } = Enum.split posts, posts_per_page

    previous = previous_page page_number
    next = next_page page_number, is_last_page(remaining)

    current
    |> posts_to_index_page(previous, next, layouts)
    |> write_index_page(path)

    _compile_index remaining, layouts, posts_per_page, page_number + 1
  end

  defp write_index_page(index_page, path) do
    File.write path, index_page.document
  end

  defp is_last_page([]), do: true
  defp is_last_page(_),  do: false

  def html_filename(page_num) do
    get_blog_index
    |> with_index_num(page_num)
    |> build_index_path
  end

  defp with_index_num(index_path_with_filename, 1), do: index_path_with_filename
  defp with_index_num(index_path_with_filename, page_number) do
    root = Path.rootname index_path_with_filename
    extension = Path.extname index_path_with_filename

    root <> to_string(page_number) <> extension
  end

  defp make_path(nil), do: nil
  defp make_path(path) do
    case get_build_path(path) do
      "./build" ->
        nil

      build_path ->
        File.mkdir_p build_path
    end
  end

  defp get_build_path(path_with_filename) do
    path = Path.dirname path_with_filename

    "./build"
    |> Path.join(path)
    |> Path.rootname
  end

  defp render_content(index_page, posts, layout) do
    params =
      [ prev: index_page.previous_page,
        next: index_page.next_page,
        content: posts
      ]

    %IndexPage{
      index_page | content: Obelisk.Renderer.render(layout, params)
    }
  end

  defp render_assets(index_page, js_assets, css_assets, layout) do
    params =
      [ js: js_assets,
        css: css_assets,
        content: index_page.content
      ]

    %IndexPage{
      index_page | document: Obelisk.Renderer.render(layout, params)
    }
  end

  defp posts_to_index_page(posts, previous, next, layouts) do
		js_assets = Obelisk.Assets.js
		css_assets = Obelisk.Assets.css

    %IndexPage{next_page: next, previous_page: previous}
    |> render_content(posts, layouts.index)
    |> render_assets(js_assets, css_assets, layouts.layout)
  end

  defp build_index_path(path), do: Path.join("./build", path)

  defp get_site_config do
    Obelisk.Config.config
  end

  defp get_blog_index do
    get_site_config[:blog_index] || "index.html"
  end

  defp get_posts_per_page do
    (get_site_config[:posts_per_page] || "10")
    |> Integer.parse
    |> elem(0)
  end

  defp build_link(path, text), do: "<a href=\"#{path}\">#{text}</a>"

  def previous_page(1),       do: ""
  def previous_page(page_num) do
    get_blog_index
    |> with_index_num(page_num - 1)
    |> build_link("Previous Page")
  end

  def next_page(_page_num, _last_page? = true), do: ""
  def next_page( page_num, _last_page? = false) do
    get_blog_index
    |> with_index_num(page_num + 1)
    |> build_link("Next Page")
  end

end
