defmodule LiveSync.WatchTest do
  use ExUnit.Case, async: true

  alias LiveSync.Example

  test "protocol implementation" do
    struct = %Example{id: "1"}
    impl = LiveSync.Watch.impl_for(struct)
    assert impl.info(struct) == {Example, "1"}
    assert impl.opts() == []
  end
end
