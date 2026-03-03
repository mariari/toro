defmodule LocalUploadWeb.UploadController do
  @moduledoc """
  I am the UploadController. I handle the web UI for browsing
  and viewing individual uploads.
  """

  use LocalUploadWeb, :controller

  alias LocalUpload.Uploads
  alias LocalUpload.Comments

  def index(conn, _params) do
    uploads = Uploads.list_recent(50)
    render(conn, :index, uploads: uploads)
  end

  @max_text_preview 64 * 1024

  def show(conn, %{"stored_name" => stored_name}) do
    upload = Uploads.get!(stored_name)
    comments = Comments.list_for_upload(stored_name)
    base_url = LocalUploadWeb.Endpoint.url()
    file_exists? = File.exists?(Uploads.file_path(upload.stored_name))

    og =
      [
        page_title: upload.original_name,
        og_title: upload.original_name,
        og_description: og_description(upload),
        og_url: "#{base_url}/u/#{upload.stored_name}"
      ] ++ og_image(base_url, upload)

    render(
      conn,
      :show,
      [
        upload: upload,
        comments: comments,
        file_exists?: file_exists?,
        text_content: text_content(upload, file_exists?)
      ] ++ og
    )
  end

  @spec og_description(Uploads.Upload.t()) :: String.t()
  defp og_description(upload) do
    "#{upload.content_type}, #{LocalUploadWeb.Helpers.format_bytes(upload.size)}"
  end

  @spec og_image(String.t(), Uploads.Upload.t()) :: keyword()
  defp og_image(base_url, %{content_type: "image/" <> _} = upload) do
    [og_image: "#{base_url}/f/#{upload.stored_name}"]
  end

  defp og_image(_, _), do: []

  @spec text_content(Uploads.Upload.t(), boolean()) :: String.t() | nil
  defp text_content(%{content_type: "text/" <> _} = upload, true) do
    path = Uploads.file_path(upload.stored_name)

    case File.read(path) do
      {:ok, data} when byte_size(data) <= @max_text_preview ->
        data

      {:ok, data} ->
        binary_part(data, 0, @max_text_preview) <> "\n… (truncated)"

      _ ->
        nil
    end
  end

  defp text_content(_, _), do: nil

  def delete(conn, %{"stored_name" => stored_name}) do
    if conn.assigns.authenticated? do
      :ok = Uploads.delete(stored_name)

      conn
      |> put_flash(:info, "File deleted.")
      |> redirect(to: ~p"/")
    else
      conn
      |> put_status(403)
      |> text("Forbidden")
      |> halt()
    end
  end
end
