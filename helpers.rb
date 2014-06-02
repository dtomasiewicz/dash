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
  def button_to(url, text, opts = {})
    method = opts[:method] || 'post'
    form_method = method.to_s == 'get' ? 'get' : 'post'
    %Q{<form action="#{h url}" method="#{form_method}" style="display: inline">}+
      %Q{<input type="hidden" name="_method" value="#{method}"><input type="submit" value="#{h text}">}+
    "</form>"
  end
end
