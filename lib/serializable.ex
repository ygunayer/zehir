defmodule Serializable do
  defmacro __using__(_args) do
    quote do
      import Serializable, only: [fields: 1, fields: 2, enum: 1, enum: 2]
    end
  end

  @doc false
  defmacro fields(opts \\ [], do: block) do
    ast = Serializable.__fields__(block, opts)

    case opts[:module] do
      nil ->
        quote do
          (fn -> unquote(ast) end).()
        end

      module ->
        quote do
          defmodule unquote(module) do
            unquote(ast)
          end
        end
    end
  end

  defmacro field(name, type, opts \\ []) do
    quote bind_quoted: [name: name, type: deref_type(type), opts: opts] do
      Serializable.__field__(name, type, opts, __ENV__)
    end
  end

  defmacro enum(values, opts \\ []) do
    quote bind_quoted: [values: values, opts: opts] do
      Serializable.__enum__(values, opts, __ENV__)
    end
  end

  @doc false
  def __fields__(block, _opts) do
    quote do
      import Serializable

      Module.register_attribute(__MODULE__, :serializable_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :serializable_field_types, accumulate: true)
      Module.register_attribute(__MODULE__, :nested_serializables, accumulate: true)
      Module.register_attribute(__MODULE__, :enum_fields, accumulate: true)

      unquote(block)

      defstruct @serializable_fields

      Serializable.__types__(@serializable_field_types)

      def deserialization_stub() do
        nested_fields =
          @nested_serializables
          |> Enum.map(fn {k, v} -> {k, resolve_module_alias(v)} end)
          |> Enum.filter(fn {_, v} -> is_serializable?(v) end)
          |> Enum.map(fn
            {k, [mod]} -> {k, [apply(mod, :deserialization_stub, [])]}
            {k, mod} -> {k, apply(mod, :deserialization_stub, [])}
          end)
          |> Map.new()

        struct(__MODULE__, nested_fields)
      end

      def parse!(json, opts \\ []) do
        Poison.decode!(json, Keyword.merge(opts, as: %__MODULE__{}))
        |> parse_nested_fields()
      end

      def parse_nested_fields(self) do
        updates =
          @serializable_fields
          |> Enum.reduce(%{}, fn {field, module}, acc ->
            if module.__info__(:functions) |> Keyword.has_key?(:parse!) do
              Map.put(acc, field, module.parse!(get_in(self, [Access.key!(field)])))
            else
              acc
            end
          end)

        self |> struct(updates)
      end
    end

    # IO.inspect(block)
  end

  def __field__(name, type, _opts, %Macro.Env{module: mod}) do
    if mod |> Module.get_attribute(:serializable_fields) |> Keyword.has_key?(name) do
      raise ArgumentError, "duplicate definitions for field #{inspect(name)}"
    end

    Module.put_attribute(mod, :serializable_fields, {name, nil})

    Module.put_attribute(mod, :serializable_field_types, {name, get_type_spec(type)})

    if maybe_module_alias?(type) do
      Module.put_attribute(mod, :nested_serializables, {name, type})
    end
  end

  def __enum__(values, _opts, _env) do
    quote bind_quoted: [values: values] do
      @enum_values unquote_splicing(values)

      @type t :: unquote_splicing(values)

      enum = Macro.escape(values)

      Enum.each(values, fn value ->
        name = Macro.escape(value)
        IO.inspect("ENUM FN #{unquote(name)} -> #{unquote(value)}")

        quote bind_quoted: [name: name, value: value] do
          def unquote(name)(), do: unquote(value)
        end
      end)

      def parse!(value), do: parse!(value, [])

      Enum.each(values, fn value ->
        def parse!(unquote(name), _), do: unquote(value)
      end)

      def parse!(nil, _), do: nil
      def parse!(value, _), do: raise(Poison.DecodeError, value: value)
    end
  end

  defmacro __types__(types) do
    quote bind_quoted: [types: types] do
      @type t :: %__MODULE__{unquote_splicing(types)}
    end
  end

  def get_type_spec(type) when is_binary(type), do: quote(do: unquote(String.to_atom(type)).t())
  def get_type_spec([type]), do: [get_type_spec(type)]
  def get_type_spec(type), do: type

  def maybe_module_alias?({{:., _, [{:__aliases__, _, _}, :t]}, _, _}), do: true
  def maybe_module_alias?(name) when is_binary(name), do: true
  def maybe_module_alias?([name]), do: maybe_module_alias?(name)

  def maybe_module_alias?(rrr) do
    IO.puts("BASKA BU #{inspect(rrr)}")
    false
  end

  def resolve_module_alias({{:., _, [{:__aliases__, _, module_path}, :t]}, _, _}),
    do: Module.concat([:"Elixir" | module_path])

  def resolve_module_alias([module_alias]), do: [resolve_module_alias(module_alias)]
  def resolve_module_alias(mod_name) when is_binary(mod_name), do: Module.concat([mod_name])
  def resolve_module_alias(module_alias), do: module_alias

  def is_serializable?({:lazy_ref, _}), do: true
  def is_serializable?([mod]), do: is_serializable?(mod)

  def is_serializable?(mod),
    do: mod.__info__(:functions) |> Keyword.has_key?(:deserialization_stub)

  defp deref_type(type) when is_binary(type), do: type
  defp deref_type(type), do: Macro.escape(type)
end
