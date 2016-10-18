defmodule S3Direct.UploadSignatureControllerTest do
  use S3Direct.ConnCase

  test "POST /", %{conn: conn} do filename = "probablyacat.jpg"
    mimetype = "image/jpeg"

    conn =
      # We'll post the filename and mimetype to the backend
      post conn, upload_signature_path(conn, :create), %{ filename: filename, mimetype: mimetype }

    response = json_response(conn, 201)
    assert response["key"] == filename
    assert response["Content-Type"] == mimetype
    assert response["acl"] == "public-read"
    assert response["success_action_status"] == "201"
    assert response["action"] =~ "s3.amazonaws.com"
    assert response["AWSAccessKeyId"]
    assert response["policy"]
    assert response["signature"]
  end
end
