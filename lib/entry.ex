defmodule Entry do
  use Serializable

  fields do
    field(:type, EntryType.t())
  end
end

defmodule EntryType do
  use Serializable

  enum("FILE", "FOLDER")
end
