# LiveSync

![coverbot](https://img.shields.io/endpoint?url=https://private.devhub.tools/coverbot/v1/devhub-tools/live_sync/main/badge.json)
[![Hex.pm](https://img.shields.io/hexpm/v/live_sync.svg)](https://hex.pm/packages/live_sync)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/live_sync)

LiveSync allows automatic updating of LiveView assigns by utilizing postgres replication.

## Installation

Add `live_sync` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_sync, "~> 0.1.0"}
  ]
end
```
