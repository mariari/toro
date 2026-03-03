defmodule EPomfRoundTrip do
  @moduledoc """
  I demonstrate the full HTTP round-trip: upload a file via the pomf
  API, then download it via the file controller and verify the bytes
  match. I build on EUpload for test data.
  """

  use ExExample
  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [build_conn: 0]
  import Plug.Conn, only: [put_req_header: 3]

  @endpoint LocalUploadWeb.Endpoint

  @spec upload_and_download() :: binary()
  example upload_and_download do
    content = "round-trip vomit test data"
    path = Path.join(System.tmp_dir!(), "roundtrip.txt")
    File.write!(path, content)

    upload = %Plug.Upload{
      path: path,
      filename: "roundtrip.txt",
      content_type: "text/plain"
    }

    # upload via pomf API
    upload_conn =
      build_conn()
      |> put_req_header("content-type", "multipart/form-data")
      |> Phoenix.ConnTest.post("/upload.php", %{
        "files" => [upload],
        "uploader" => "tester"
      })

    json = Phoenix.json_library().decode!(upload_conn.resp_body)
    assert json["success"] == true

    [file] = json["files"]
    assert file["name"] == "roundtrip.txt"
    assert file["size"] == byte_size(content)

    # extract stored name from URL
    "/u/" <> stored_name = URI.parse(file["url"]).path

    # download via file controller
    download_conn =
      build_conn()
      |> Phoenix.ConnTest.get("/f/#{stored_name}")

    assert download_conn.status == 200
    assert download_conn.resp_body == content

    assert Plug.Conn.get_resp_header(download_conn, "content-type")
           |> hd()
           |> String.starts_with?("text/plain")

    download_conn.resp_body
  end

  @spec file_not_found() :: integer()
  example file_not_found do
    conn =
      build_conn()
      |> Phoenix.ConnTest.get("/f/nonexistent.txt")

    assert conn.status == 404
    conn.status
  end

  @spec path_traversal_blocked() :: integer()
  example path_traversal_blocked do
    conn =
      build_conn()
      |> Phoenix.ConnTest.get("/f/..%2fmix.exs")

    assert conn.status == 400
    conn.status
  end

  @spec rerun?(any()) :: boolean()
  def rerun?(_), do: false
end
