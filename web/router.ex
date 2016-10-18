defmodule S3Direct.Router do
  use S3Direct.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", S3Direct do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  scope "/api", S3Direct do
    pipe_through :api

    resources "/upload_signatures", UploadSignatureController, only: [:create]
  end
end
