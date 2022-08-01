defmodule NoisemakerTest do
  use ExUnit.Case
  doctest Noisemaker

  test "greets the world" do
    assert Noisemaker.hello() == :world
  end
end
