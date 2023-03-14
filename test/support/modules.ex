defmodule Foo do
  use Serializable

  fields do
    field(:bar, "Bar")
    field(:quux, String.t())
    field(:piyo, [Piyo.t()])
  end
end

defmodule Bar do
  use Serializable

  fields do
    field(:baz, integer())
  end
end

defmodule Piyo do
  use Serializable

  fields do
    field(:key, HogeOrPiyo.t())
    field(:value, String.t())
  end
end

# defmodule HogeOrPiyo do
#  use Serializable

#  enum([
#    :HOGE,
#    :PIYO
#  ])
# end
