helpers do
  def h text
    Rack::Utils.escape_html text
  end
  def link_to url, text = nil
    %Q{<a href="#{h url}">#{h(text || url)}</a>}
  end
  def escape(str)
    Rack::Utils.escape str
  end
  def unescape(str)
    Rack::Utils.unescape str
  end
end
