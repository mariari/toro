defmodule LocalUploadWeb.PomfController do
  @moduledoc """
  I am the PomfController. I implement the pomf upload protocol
  for vomitchan compatibility.
  """

  use LocalUploadWeb, :controller

  alias LocalUpload.Uploads
  alias LocalUpload.Uploads.PomfResponse

  @doc "I handle pomf-compatible file uploads."
  @spec upload(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def upload(conn, params) do
    case check_secret(params) do
      :ok ->
        do_upload(conn, params)

      :unauthorized ->
        conn
        |> put_status(403)
        |> json(PomfResponse.to_json(PomfResponse.error(403, "Invalid secret")))
    end
  end

  @spec check_secret(map()) :: :ok | :unauthorized
  defp check_secret(params) do
    case Application.get_env(:local_upload, :upload_secret) do
      nil -> :ok
      secret -> if params["secret"] == secret, do: :ok, else: :unauthorized
    end
  end

  @spec do_upload(Plug.Conn.t(), map()) :: Plug.Conn.t()
  defp do_upload(conn, %{"files" => files} = params) when is_list(files) do
    uploader = Map.get(params, "uploader", "anonymous")

    results =
      Enum.map(files, fn %Plug.Upload{} = file ->
        with {:ok, upload} <- Uploads.store_file(file, uploader) do
          base_url = LocalUploadWeb.Endpoint.url()

          %{
            hash: upload.hash,
            name: upload.original_name,
            url: "#{base_url}/u/#{upload.stored_name}",
            size: upload.size
          }
        end
      end)

    case Enum.split_with(results, &is_map/1) do
      {file_entries, []} ->
        json(conn, PomfResponse.to_json(PomfResponse.success(file_entries)))

      {_, _errors} ->
        conn
        |> put_status(500)
        |> json(PomfResponse.to_json(PomfResponse.error(500, "Upload failed")))
    end
  end

  defp do_upload(conn, _params) do
    conn
    |> put_status(400)
    |> json(PomfResponse.to_json(PomfResponse.error(400, "No input file(s)")))
  end
end
