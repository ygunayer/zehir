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

      Module.register_attribute(__MODULE__, :zehir_types, accumulate: true)
      Module.register_attribute(__MODULE__, :zehir_maybe_nesteds, accumulate: true)
      Module.register_attribute(__MODULE__, :zehir_maybe_enums, accumulate: true)

      unquote(block)

      defstruct @zehir_types

      Serializable.__types__(@zehir_types)

      def deserialization_stub() do
        IO.puts("ANANINKI #{inspect(@zehir_maybe_nesteds)}")

        nested_fields =
          @zehir_maybe_nesteds
          |> Enum.map(fn {field, type} -> {field, resolve_module_alias(type)} end)
          |> Enum.filter(fn {_, module} -> has_method?(module, :deserialization_stub) end)
          |> Enum.map(fn
            {k, [mod]} -> {k, [apply(mod, :deserialization_stub, [])]}
            {k, mod} -> {k, apply(mod, :deserialization_stub, [])}
          end)
          |> Map.new()

        struct(__MODULE__, nested_fields)
      end

      def parse!(json, opts \\ []) do
        Poison.decode!(json, Keyword.merge(opts, as: deserialization_stub()))
      end

      def assign_enums(self) do
        IO.inspect(@zehir_maybe_enums)

        updates =
          @zehir_maybe_enums
          |> Enum.map(fn {field, type} -> {field, resolve_module_alias(type)} end)
          |> Enum.filter(fn {_, module} -> has_method?(module, :enum_value_from_binary!) end)
          |> Enum.map(fn {field, module}, acc ->
            value =
              get_in(self, [Access.key!(field)])
              |> module.enum_value_from_binary!()

            {field, value}
          end)
          |> Map.new()

        self |> struct(updates)
      end
    end
  end

  defmacro __types__(types) do
    quote bind_quoted: [types: types] do
      @type t :: %__MODULE__{unquote_splicing(types)}
    end
  end

  def __field__(name, type, _opts, %Macro.Env{module: mod}) do
    if mod |> Module.get_attribute(:zehir_types) |> Keyword.has_key?(name) do
      raise ArgumentError, "duplicate definitions for field #{inspect(name)}"
    end

    Module.put_attribute(mod, :zehir_types, {name, get_type_spec(type)})

    # field_module = real_module(type)

    if is_module_alias?(type) do
      Module.put_attribute(mod, :zehir_maybe_nesteds, {name, type})
      Module.put_attribute(mod, :zehir_maybe_enums, {name, type})
    end
  end

  def __enum__(values, _opts, _env) do
    quote bind_quoted: [values: values] do
      @enum_values unquote_splicing(values)

      @type t :: unquote_splicing(values)

      enum = Macro.escape(values)

      def enum_value_from_binary!(value), do: raise("TODO #{inspect(enum)}")
    end
  end

  # Runtime methods
  def has_method?(module, method), do: module.__info__(:functions) |> Keyword.has_key?(method)

  # Macro-related
  def get_type_spec(type) when is_binary(type), do: quote(do: unquote(String.to_atom(type)).t())
  def get_type_spec([type]), do: [get_type_spec(type)]
  def get_type_spec(type), do: type

  def is_module_alias?([mod]), do: is_module_alias?(mod)
  def is_module_alias?({{:., _, [{:__aliases__, _, _module_path}, :t]}, _, _}), do: true
  def is_module_alias?(mod_name) when is_binary(mod_name), do: true
  def is_module_alias?(_), do: false

  def maybe_nested_field?(name) when is_binary(name), do: true
  def maybe_nested_field?([name]), do: maybe_nested_field?(name)
  def maybe_nested_field?(module), do: has_method?(module, :parse!)

  def maybe_enum?(name) when is_binary(name), do: true
  def maybe_enum?([name]), do: maybe_enum?(name)
  def maybe_enum?(module), do: has_method?(module, :enum_value_from_binary!)

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
