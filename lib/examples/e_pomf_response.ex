defmodule EPomfResponse do
  @moduledoc """
  I demonstrate building pomf JSON responses from uploads.
  I build on EUpload.
  """

  use ExExample
  import ExUnit.Assertions

  alias LocalUpload.Uploads.PomfResponse

  @spec success_response() :: map()
  example success_response do
    upload = EUpload.create_upload()

    file_entry = %{
      hash: upload.hash,
      name: upload.original_name,
      url: "http://localhost:4000/u/#{upload.stored_name}",
      size: upload.size
    }

    response = PomfResponse.success([file_entry])
    json = PomfResponse.to_json(response)

    assert json["success"] == true
    assert length(json["files"]) == 1

    [file] = json["files"]
    assert file.name == "test_vomit.txt"
    assert String.contains?(file.url, "/u/")

    json
  end

  @spec error_response() :: map()
  example error_response do
    response = PomfResponse.error(400, "No input file(s)")
    json = PomfResponse.to_json(response)

    assert json["success"] == false
    assert json["errorcode"] == 400
    assert json["description"] == "No input file(s)"

    json
  end

  @spec rerun?(any()) :: boolean()
  def rerun?(_), do: false
end
