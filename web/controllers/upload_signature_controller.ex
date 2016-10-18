defmodule S3Direct.UploadSignatureController do
  use S3Direct.Web, :controller

  def create(conn, %{"filename" => filename, "mimetype" => mimetype}) do
    conn
    |> put_status(:created)
    |> render("create.json", signature: sign(filename, mimetype))
  end


  defp sign(filename, mimetype) do
    policy = policy(filename, mimetype)

    %{
      key: filename,
      'Content-Type': mimetype,
      acl: "public-read",
      success_action_status: "201",
      action: bucket_url(),
      'AWSAccessKeyId': aws_access_key_id(),
      policy: policy,
      signature: hmac_sha1(aws_secret_key(), policy)
    }
  end

  defp hmac_sha1(secret, msg) do
    :crypto.hmac(:sha, secret, msg)
      |> Base.encode64
  end

  defp now_plus(minutes) do
    import Timex

    now
      |> shift(minutes: minutes)
      |> format!("{ISO:Extended:Z}")
  end

  defp policy(key, mimetype, expiration_window \\ 60) do
    %{
      expiration: now_plus(expiration_window),
      conditions: [
        %{ bucket: bucket_name },
        %{ acl: "public-read"},
        ["starts-with", "$Content-Type", mimetype],
        ["starts-with", "$key", key],
        %{ success_action_status: "201" }
      ]
    }
    |> Poison.encode!
    |> Base.encode64
  end

  def aws_access_key_id() do
    Application.get_env(:s3_direct, :aws)[:access_key_id]
  end

  def aws_secret_key() do
    Application.get_env(:s3_direct, :aws)[:secret_key]
  end

  defp bucket_name() do
    Application.get_env(:s3_direct, :aws)[:bucket_name]
  end

  defp bucket_url() do
    "https://s3.amazonaws.com/#{bucket_name()}"
  end
end
