helpers do
  def h text
    Rack::Utils.escape_html text
  end
  def link_to url, text = nil
    %Q{<a href="#{h url}">#{h(text || url)}</a>}
  end
end
