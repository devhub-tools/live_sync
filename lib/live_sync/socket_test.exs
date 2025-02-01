defmodule LiveSync.SocketTest do
  use LiveSync.DataCase

  import Phoenix.LiveViewTest

  alias LiveSync.Example
  alias LiveSync.Repo

  @endpoint LiveSync.Endpoint

  setup do
    LiveSync.start_link(repo: LiveSync.Repo, otp_app: :live_sync)
    :ok
  end

  test "updates reflect in renders" do
    example = Repo.insert!(%Example{name: "replication", enabled: false})

    {:ok, view, html} =
      live_isolated(Phoenix.ConnTest.build_conn(), LiveSync.LivePage, session: %{"id" => example.id, "test" => self()})

    parsed_html = Floki.parse_document!(html)
    assert parsed_html |> Floki.find("#data-name") |> Floki.text() == "replication"
    assert parsed_html |> Floki.find("#data-enabled") |> Floki.text() == "false"

    assert [
             {"div", [],
              [
                {"p", [{"class", "example-id"}], [example.id]},
                {"p", [{"class", "example-name"}], ["replication"]},
                {"p", [{"class", "example-enabled"}], ["false"]}
              ]}
           ] == Floki.find(parsed_html, "#examples > div")

    # update record
    example = Repo.update!(change(example, name: "more replication", enabled: true))

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)

    assert parsed_html |> Floki.find("#data-name") |> Floki.text() == "more replication"
    assert parsed_html |> Floki.find("#data-enabled") |> Floki.text() == "true"

    assert [
             {"div", [],
              [
                {"p", [{"class", "example-id"}], [example.id]},
                {"p", [{"class", "example-name"}], ["more replication"]},
                {"p", [{"class", "example-enabled"}], ["true"]}
              ]}
           ] == Floki.find(parsed_html, "#examples > div")

    # add a record
    another_example = Repo.insert!(%Example{name: "new replication", enabled: false})

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)

    assert [
             {"div", [],
              [
                {"p", [{"class", "example-id"}], [example.id]},
                {"p", [{"class", "example-name"}], ["more replication"]},
                {"p", [{"class", "example-enabled"}], ["true"]}
              ]},
             {"div", [],
              [
                {"p", [{"class", "example-id"}], [another_example.id]},
                {"p", [{"class", "example-name"}], ["new replication"]},
                {"p", [{"class", "example-enabled"}], ["false"]}
              ]}
           ] == Floki.find(parsed_html, "#examples > div")

    # sync callback is handled and sorting applied
    another_example = Repo.update!(change(another_example, name: "aaa", enabled: true))

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)

    assert [
             {"div", [],
              [
                {"p", [{"class", "example-id"}], [another_example.id]},
                {"p", [{"class", "example-name"}], ["aaa"]},
                {"p", [{"class", "example-enabled"}], ["true"]}
              ]},
             {"div", [],
              [
                {"p", [{"class", "example-id"}], [example.id]},
                {"p", [{"class", "example-name"}], ["more replication"]},
                {"p", [{"class", "example-enabled"}], ["true"]}
              ]}
           ] == Floki.find(parsed_html, "#examples > div")

    # delete records
    Repo.delete!(example)

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)

    refute has_element?(view, "#data")

    assert [
             {"div", [],
              [
                {"p", [{"class", "example-id"}], [another_example.id]},
                {"p", [{"class", "example-name"}], ["aaa"]},
                {"p", [{"class", "example-enabled"}], ["true"]}
              ]}
           ] == Floki.find(parsed_html, "#examples > div")

    Repo.delete!(another_example)

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)

    assert [] == Floki.find(parsed_html, "#examples > div")

    # can insert into empty list
    example = Repo.insert!(%Example{name: "replication", enabled: false})

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)

    assert [
             {"div", [],
              [
                {"p", [{"class", "example-id"}], [example.id]},
                {"p", [{"class", "example-name"}], ["replication"]},
                {"p", [{"class", "example-enabled"}], ["false"]}
              ]}
           ] == Floki.find(parsed_html, "#examples > div")
  end
end
