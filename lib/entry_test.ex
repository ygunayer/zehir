json = "{\"name\":\"foo.txt\",\"type\":\"FILE\"}"

expected_parsed = %Entry{
  name: "foo.txt",
  type: :FILE
}

actual_parsed = Entry.parse!(json)
IO.puts("Deserialization:")
IO.puts("==============")
IO.puts("Expected: #{inspect(expected_parsed)}")
IO.puts("Actual: #{inspect(actual_parsed)}")
IO.puts("Matches? #{actual_parsed == expected_parsed}")

IO.puts("")

actual_serialized = Poison.encode!(expected_parsed)
IO.puts("Serialization")
IO.puts("==============")
IO.puts("Expected: #{json}")
IO.puts("Actual: #{actual_serialized}")
IO.puts("Matches? #{actual_serialized == json}")
