json = "{\"type\":\"FILE\"}"

parsed = Entry.parse!(json)
serialized = Poison.encode!(parsed)

IO.inspect(parsed)
IO.puts(serialized)
IO.puts(json)
IO.inspect(serialized == json)
