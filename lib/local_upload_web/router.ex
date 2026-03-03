defmodule LocalUploadWeb.Router do
  use LocalUploadWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_root_layout, html: {LocalUploadWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug LocalUploadWeb.Plugs.IPHash
    plug LocalUploadWeb.Plugs.Auth
  end

  pipeline :pomf_api do
    plug :accepts, ["json"]
  end

  # Pomf-compatible upload API (no CSRF — stateless bot protocol)
  scope "/", LocalUploadWeb do
    pipe_through :pomf_api

    post "/upload.php", PomfController, :upload
  end

  # File serving (outside pipelines — just sends bytes)
  scope "/f", LocalUploadWeb do
    get "/:name", FileController, :show
  end

  # Short alias for upload page
  scope "/u", LocalUploadWeb do
    pipe_through :browser

    get "/:stored_name", UploadController, :show
  end

  # Web UI
  scope "/", LocalUploadWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/admin", AdminController, :index
    get "/auth", AuthController, :new
    post "/auth", AuthController, :create
    delete "/auth", AuthController, :delete
    get "/browse", UploadController, :index
    get "/uploads/:stored_name", UploadController, :show
    delete "/uploads/:stored_name", UploadController, :delete
    post "/uploads/:stored_name/comments", CommentController, :create
    post "/uploads/:stored_name/vote", VoteController, :create
  end
end
