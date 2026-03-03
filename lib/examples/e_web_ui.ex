defmodule EWebUI do
  @moduledoc """
  I demonstrate the web UI controllers: homepage, browse page,
  show page, voting, and commenting — all via HTTP. I build on
  EUpload for test data.
  """

  use ExExample
  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [build_conn: 0]
  import Plug.Conn, only: [put_req_header: 3]

  alias LocalUpload.Uploads

  @endpoint LocalUploadWeb.Endpoint

  @spec homepage() :: Plug.Conn.t()
  example homepage do
    _upload = EUpload.create_upload()

    conn =
      build_conn()
      |> Phoenix.ConnTest.get("/")

    assert conn.status == 200
    assert conn.resp_body =~ "Top Vomited Files This Week"
    assert conn.resp_body =~ "Recent Uploads"

    conn
  end

  @spec browse_page() :: Plug.Conn.t()
  example browse_page do
    _upload = EUpload.create_upload()

    conn =
      build_conn()
      |> Phoenix.ConnTest.get("/browse")

    assert conn.status == 200
    assert conn.resp_body =~ "Recent Uploads"
    assert conn.resp_body =~ "test_vomit.txt"

    conn
  end

  @spec show_page() :: Plug.Conn.t()
  example show_page do
    upload = EUpload.create_upload()

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{authenticated: true})
      |> Phoenix.ConnTest.get("/uploads/#{upload.stored_name}")

    assert conn.status == 200
    assert conn.resp_body =~ upload.original_name
    assert conn.resp_body =~ "Vomited by"
    assert conn.resp_body =~ upload.uploader
    assert conn.resp_body =~ "Add a Comment"

    conn
  end

  @spec vote_via_http() :: Plug.Conn.t()
  example vote_via_http do
    upload = EUpload.create_upload()
    before = Uploads.get!(upload.stored_name).vote_count

    # vote
    vote_conn =
      build_conn()
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Phoenix.ConnTest.post("/uploads/#{upload.stored_name}/vote")

    assert vote_conn.status == 302

    # verify count incremented
    refreshed = Uploads.get!(upload.stored_name)
    assert refreshed.vote_count == before + 1

    # voting again from same IP is idempotent
    vote_conn2 =
      build_conn()
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Phoenix.ConnTest.post("/uploads/#{upload.stored_name}/vote")

    assert vote_conn2.status == 302

    after_dup = Uploads.get!(upload.stored_name)
    assert after_dup.vote_count == before + 1

    vote_conn
  end

  @spec comment_via_http() :: Plug.Conn.t()
  example comment_via_http do
    # fresh upload to avoid shared state with vote_via_http
    path = Path.join(System.tmp_dir!(), "comment_test.txt")
    File.write!(path, "comment test #{System.unique_integer()}")

    {:ok, upload} =
      LocalUpload.Uploads.store_file(
        %Plug.Upload{path: path, filename: "comment_test.txt", content_type: "text/plain"},
        "commenter"
      )

    conn =
      build_conn()
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Phoenix.ConnTest.post(
        "/uploads/#{upload.stored_name}/comments",
        %{"comment" => %{"body" => "nice vomit!", "author_name" => "tester"}}
      )

    assert conn.status == 302

    # verify comment exists on show page
    show_conn =
      build_conn()
      |> Phoenix.ConnTest.get("/uploads/#{upload.stored_name}")

    assert show_conn.resp_body =~ "nice vomit!"
    assert show_conn.resp_body =~ "tester"

    conn
  end

  @spec rerun?(any()) :: boolean()
  def rerun?(_), do: false
end
