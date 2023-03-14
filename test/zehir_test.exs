defmodule ZehirTest do
  use ExUnit.Case
  doctest Zehir

  test "should deserialize from JSON" do
    input = File.read!("test/support/fixtures/foo.json")
    expected = TestData.foo()
    actual = Poison.decode!(input, as: Foo.deserialization_stub())
    assert actual == expected
  end

  test "should deserialize from nested JSON" do
    input = File.read!("test/support/fixtures/nested_foo.json")
    expected = TestData.foo()
    %{"foo" => actual} = Poison.decode!(input, as: %{"foo" => Foo.deserialization_stub()})
    assert actual == expected
  end

  test "should deserialize from what was serialized" do
    expected = TestData.foo()
    input = Poison.encode!(expected)
    actual = Poison.decode!(input, as: Foo.deserialization_stub())
    assert actual == expected
  end
end
