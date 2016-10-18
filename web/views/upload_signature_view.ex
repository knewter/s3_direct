defmodule S3Direct.UploadSignatureView do
  use S3Direct.Web, :view

  def render("create.json", %{signature: signature}) do
    signature
  end
end
