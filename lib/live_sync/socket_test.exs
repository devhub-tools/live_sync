defmodule LiveSync.SocketTest do
  use LiveSync.ConnCase

  alias LiveSync.Example
  alias LiveSync.Ignored
  alias LiveSync.Repo

  setup do
    LiveSync.start_link(repo: LiveSync.Repo, otp_app: :live_sync)
    :ok
  end

  test "updates reflect in renders", %{conn: conn} do
    example = Repo.insert!(%Example{organization_id: 1, name: "replication", enabled: false})

    {:ok, view, html} = conn |> get("/#{example.id}") |> live()

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
    another_example = Repo.insert!(%Example{organization_id: 1, name: "new replication", enabled: false})

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
    example = Repo.insert!(%Example{organization_id: 1, name: "replication", enabled: false})

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

  test "works with associations", %{conn: conn} do
    parent = Repo.insert!(%Example{organization_id: 1, name: "parent", enabled: false})
    example = Repo.insert!(%Example{organization_id: 1, name: "replication", enabled: false, parent_id: parent.id})

    {:ok, view, html} = conn |> get("/#{example.id}") |> live()

    parsed_html = Floki.parse_document!(html)
    assert parsed_html |> Floki.find("#data-parent-name") |> Floki.text() == "parent"

    parent = Repo.update!(change(parent, name: "my parent"))

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)
    assert parsed_html |> Floki.find("#data-parent-name") |> Floki.text() == "my parent"

    # load from parent and insert child
    {:ok, view, html} = conn |> get("/#{parent.id}") |> live()

    parsed_html = Floki.parse_document!(html)

    assert [
             {"p", [{"class", "data-child-name"}], ["replication"]}
           ] == Floki.find(parsed_html, ".data-child-name")

    Repo.insert!(%Example{organization_id: 1, name: "child", enabled: false, parent_id: parent.id})

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)

    assert [
             {"p", [{"class", "data-child-name"}], ["child"]},
             {"p", [{"class", "data-child-name"}], ["replication"]}
           ] == Floki.find(parsed_html, ".data-child-name")
  end

  test "ignores non-watched schemas", %{conn: conn} do
    example = Repo.insert!(%Example{organization_id: 1, name: "replication", enabled: false})
    ignore = Repo.insert!(%Ignored{organization_id: 1, name: "ignore", example_id: example.id})

    {:ok, view, html} = conn |> get("/#{example.id}") |> live()

    parsed_html = Floki.parse_document!(html)
    assert parsed_html |> Floki.find("#data-name") |> Floki.text() == "replication"
    assert parsed_html |> Floki.find(".data-ignored-name") |> Floki.text() == "ignore"

    _ignore = Repo.update!(change(ignore, name: "still ignored"))
    refute_receive :synced

    _ignore = Repo.update!(change(example, name: "not ignored"))
    assert_receive :synced

    html = render(view)
    parsed_html = Floki.parse_document!(html)
    assert parsed_html |> Floki.find("#data-name") |> Floki.text() == "not ignored"
    assert parsed_html |> Floki.find(".data-ignored-name") |> Floki.text() == "ignore"
  end

  test "can change belongs_to foreign key", %{conn: conn} do
    parent = Repo.insert!(%Example{organization_id: 1, name: "parent", enabled: false})
    other_parent = Repo.insert!(%Example{organization_id: 1, name: "other parent", enabled: false})
    example = Repo.insert!(%Example{organization_id: 1, name: "replication", enabled: false, parent_id: parent.id})

    {:ok, view, html} = conn |> get("/#{example.id}") |> live()

    parsed_html = Floki.parse_document!(html)
    assert parsed_html |> Floki.find("#data-parent-name") |> Floki.text() == "parent"

    Repo.update!(change(example, parent_id: other_parent.id))

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)
    assert parsed_html |> Floki.find("#data-parent-name") |> Floki.text() == "other parent"
  end

  test "can change has_many foreign key", %{conn: conn} do
    parent = Repo.insert!(%Example{organization_id: 1, name: "parent", enabled: false})
    _child1 = Repo.insert!(%Example{organization_id: 1, name: "child1", enabled: false, parent_id: parent.id})
    child2 = Repo.insert!(%Example{organization_id: 1, name: "child2", enabled: false, parent_id: parent.id})

    {:ok, view, html} = conn |> get("/#{parent.id}") |> live()

    parsed_html = Floki.parse_document!(html)

    assert [
             {"p", [{"class", "data-child-name"}], ["child1"]},
             {"p", [{"class", "data-child-name"}], ["child2"]}
           ] == Floki.find(parsed_html, ".data-child-name")

    Repo.update!(change(child2, parent_id: nil))

    assert_receive :synced
    html = render(view)

    parsed_html = Floki.parse_document!(html)

    assert [
             {"p", [{"class", "data-child-name"}], ["child1"]}
           ] == Floki.find(parsed_html, ".data-child-name")
  end
end
