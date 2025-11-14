defmodule DisplayNameCreationTest do
  use ExUnit.Case

  alias OpcUA.{Server, Client, NodeId, QualifiedName}

  @moduledoc """
  Test that demonstrates the new display_name and description parameters
  during node creation with locale support (en-US).
  """

  setup do
    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_default_config(s_pid)
    :ok = Server.set_port(s_pid, 4200)
    {:ok, ns_index} = Server.add_namespace(s_pid, "TestDisplayName")
    :ok = Server.start(s_pid)

    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)
    :ok = Client.connect_by_url(c_pid, url: "opc.tcp://localhost:4200/")

    on_exit(fn ->
      if Process.alive?(c_pid), do: Client.stop(c_pid)
      if Process.alive?(s_pid), do: Server.stop(s_pid)
    end)

    %{s_pid: s_pid, c_pid: c_pid, ns_index: ns_index}
  end

  @tag :integration
  test "Node created with localized displayName and description", %{
    s_pid: s_pid,
    c_pid: c_pid,
    ns_index: ns_index
  } do
    node_id = NodeId.new(ns_index: ns_index, identifier_type: "integer", identifier: 3001)
    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "TestNode")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)

    # Create node with localized displayName and description
    :ok =
      Server.add_variable_node(s_pid,
        requested_new_node_id: node_id,
        parent_node_id: parent_node_id,
        reference_type_node_id: reference_type_node_id,
        browse_name: browse_name,
        type_definition: type_definition,
        display_name: {"en-US", "My Test Node"},
        description: {"en-US", "This is a test node with localized description"}
      )

    # Set permissions
    :ok = Server.write_node_write_mask(s_pid, node_id, 0xFFFFFFFF)
    :ok = Server.write_node_access_level(s_pid, node_id, 3)

    # Read displayName - should have locale "en-US" because it was set during creation
    {:ok, {display_locale, display_text}} = Client.read_node_display_name(c_pid, node_id)

    assert display_locale == "en-US", "DisplayName should have en-US locale when set during creation"
    assert display_text == "My Test Node", "DisplayName text should match what was set"

    # Read description
    {:ok, {desc_locale, desc_text}} = Client.read_node_description(c_pid, node_id)

    assert desc_locale == "en-US", "Description should have en-US locale when set during creation"
    assert desc_text == "This is a test node with localized description", "Description text should match"
  end

  @tag :integration
  test "Node created without explicit displayName/description uses defaults", %{
    s_pid: s_pid,
    c_pid: c_pid,
    ns_index: ns_index
  } do
    node_id = NodeId.new(ns_index: ns_index, identifier_type: "integer", identifier: 3002)
    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "DefaultNode")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)

    # Create node WITHOUT specifying displayName or description (uses defaults)
    :ok =
      Server.add_variable_node(s_pid,
        requested_new_node_id: node_id,
        parent_node_id: parent_node_id,
        reference_type_node_id: reference_type_node_id,
        browse_name: browse_name,
        type_definition: type_definition
      )

    # Set permissions
    :ok = Server.write_node_write_mask(s_pid, node_id, 0xFFFFFFFF)
    :ok = Server.write_node_access_level(s_pid, node_id, 3)

    # Read displayName
    {:ok, {display_locale, display_text}} = Client.read_node_display_name(c_pid, node_id)

    # When displayName text is empty (""), open62541 uses browse_name as the displayName text
    # and the locale becomes empty string instead of "en-US"
    assert display_locale == "", "When displayName text is empty, locale becomes empty too"
    assert display_text == "DefaultNode", "DisplayName falls back to browse_name when text is empty"

    # Read description
    {:ok, {desc_locale, desc_text}} = Client.read_node_description(c_pid, node_id)

    # Description also gets empty locale when text is empty
    assert desc_locale == "", "When description text is empty, locale becomes empty"
    assert desc_text == "", "Description text should be empty"
  end

  @tag :integration
  test "Localized displayName can be modified after creation", %{
    s_pid: s_pid,
    c_pid: c_pid,
    ns_index: ns_index
  } do
    node_id = NodeId.new(ns_index: ns_index, identifier_type: "integer", identifier: 3003)
    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "ModifiableNode")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)

    # Create node with initial localized displayName
    :ok =
      Server.add_variable_node(s_pid,
        requested_new_node_id: node_id,
        parent_node_id: parent_node_id,
        reference_type_node_id: reference_type_node_id,
        browse_name: browse_name,
        type_definition: type_definition,
        display_name: {"en-US", "Initial Name"}
      )

    # Set permissions
    :ok = Server.write_node_write_mask(s_pid, node_id, 0xFFFFFFFF)
    :ok = Server.write_node_access_level(s_pid, node_id, 3)

    # Verify initial displayName
    {:ok, {display_locale, display_text}} = Client.read_node_display_name(c_pid, node_id)
    assert display_locale == "en-US"
    assert display_text == "Initial Name"

    # Modify displayName via Server (keeping the locale)
    :ok = Server.write_node_display_name(s_pid, node_id, "en-US", "Modified by Server")

    # Verify Server modification
    {:ok, {server_locale, server_text}} = Client.read_node_display_name(c_pid, node_id)

    assert server_locale == "en-US", "Locale should remain en-US after Server write"
    assert server_text == "Modified by Server", "DisplayName text should be updated by Server"

    # Modify displayName via Client (keeping the locale)
    :ok = Client.write_node_display_name(c_pid, node_id, "en-US", "Modified by Client")

    # Verify Client modification
    {:ok, {client_locale, client_text}} = Client.read_node_display_name(c_pid, node_id)

    assert client_locale == "en-US", "Locale should remain en-US after Client write"
    assert client_text == "Modified by Client", "DisplayName text should be updated by Client"
  end
end
