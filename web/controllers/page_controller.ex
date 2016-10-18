defmodule S3Direct.PageController do
  use S3Direct.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
