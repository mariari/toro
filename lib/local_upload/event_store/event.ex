defmodule LocalUpload.EventStore.Event do
  @moduledoc "I am an immutable fact. I record something that happened."

  use Ecto.Schema
  use GtBridge.View

  import Ecto.Changeset

  alias GtBridge.Phlow.ColumnedList
  alias GtBridge.Phlow.List, as: PhlowList
  alias GtBridge.Phlow.Text
  alias LocalUpload.ProjectionStore

  @derive {Jason.Encoder, except: [:__meta__]}

  @type t :: %__MODULE__{
          id: integer() | nil,
          type: String.t() | nil,
          data: map() | nil,
          aggregate_id: integer() | nil,
          inserted_at: DateTime.t() | nil
        }

  schema "events" do
    field :type, :string
    field :data, :map
    field :aggregate_id, :integer

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:type, :data, :aggregate_id])
    |> validate_required([:type, :data])
  end

  ############################################################
  #                        GT Views                          #
  ############################################################

  @spec event_view(t(), GtBridge.Phlow.Builder) :: Text.t()
  defview event_view(self = %__MODULE__{}, builder) do
    builder.text()
    |> Text.title("Event")
    |> Text.priority(1)
    |> Text.monospace()
    |> Text.font_size(14)
    |> Text.string(fn ->
      data_str =
        self.data
        |> Enum.map_join("\n  ", fn {k, v} -> "#{k}: #{inspect(v)}" end)

      "[#{self.type}] at #{self.inserted_at}\n  #{data_str}"
    end)
  end

  @spec object_view(t(), GtBridge.Phlow.Builder) :: PhlowList.t()
  defview object_view(self = %__MODULE__{}, builder) do
    builder.list()
    |> PhlowList.title("Object")
    |> PhlowList.priority(2)
    |> PhlowList.items(fn -> resolve_objects(self) end)
    |> PhlowList.item_format(fn
      %LocalUpload.Uploads.Upload{} = u -> "Upload: #{u.original_name}"
      %LocalUpload.Comments.Comment{} = c -> "Comment: #{c.author_name}"
      other -> inspect(other)
    end)
  end

  @spec data_view(t(), GtBridge.Phlow.Builder) :: ColumnedList.t()
  defview data_view(self = %__MODULE__{}, builder) do
    builder.columned_list()
    |> ColumnedList.title("Data")
    |> ColumnedList.priority(3)
    |> ColumnedList.items(fn -> Enum.to_list(self.data || %{}) end)
    |> ColumnedList.column("Key", fn {k, _v} -> to_string(k) end)
    |> ColumnedList.column("Value", fn {_k, v} -> inspect(v) end)
  end

  ############################################################
  #                   Private Implementation                 #
  ############################################################

  defp resolve_objects(%__MODULE__{type: "comment_added", id: id, data: data}) do
    stored_name = data["stored_name"]
    upload = ProjectionStore.get_upload(stored_name)

    comment =
      stored_name
      |> ProjectionStore.list_comments()
      |> Enum.find(&(&1.mono_id == id))

    Enum.reject([upload, comment], &is_nil/1)
  end

  defp resolve_objects(%__MODULE__{data: data}) do
    case data["stored_name"] do
      nil -> []
      name -> [ProjectionStore.get_upload(name)] |> Enum.reject(&is_nil/1)
    end
  end
end
