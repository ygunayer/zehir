defmodule TestData do
  def foo() do
    %Foo{
      bar: %Bar{
        baz: 42
      },
      quux: "hoge",
      piyo: [
        %Piyo{key: :HOGE, value: "p"},
        %Piyo{key: :PIYO, value: "i"},
        %Piyo{key: :HOGE, value: "y"},
        %Piyo{key: :PIYO, value: "o"}
      ]
    }
  end
end
