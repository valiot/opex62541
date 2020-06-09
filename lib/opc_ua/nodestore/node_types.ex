defmodule OpcUA.BaseNodeAttrs do
  @moduledoc """
    Base Node Attributes

    Nodes contain attributes according to their node type. The base node
    attributes are common to all node types. In the OPC UA `services`,
    attributes are referred to via the `nodeid` of the containing node and
    an integer `attribute-id`.

    In opex62541 we set `node_id` during the node definition.

    TODO: add node_id, node_class, references_size, :reference backend
  """
  @doc false
  def basic_nodes_attrs(), do: [:browse_name, :display_name, :description, :write_mask, :args]
end

defmodule OpcUA.VariableNode do
  use IsEnumerable
  use IsAccessible

  import OpcUA.BaseNodeAttrs

  @moduledoc """
    VariableNode

    Variables store values in a `value` together with metadata for introspection.
    Most notably, the attributes data type, `value_rank` and array dimensions constrain the possible values the variable can take
    on.

    Variables come in two flavours: properties and datavariables. Properties are
    related to a parent with a ``hasProperty`` reference and may not have child
    nodes themselves. Datavariables may contain properties (``hasProperty``) and
    also datavariables (``hasComponents``).

    All variables are instances of some `variabletypenode` in return
    constraining the possible data type, value rank and array dimensions
    attributes.

    Data Type

    The (scalar) data type of the variable is constrained to be of a specific
    type or one of its children in the type hierarchy. The data type is given as
    a NodeId pointing to a `DataTypeNode` in the type hierarchy. See the
    Section `DataTypeNode` for more details.

    If the data type attribute points to ``UInt32``, then the value attribute
    must be of that exact type since ``UInt32`` does not have children in the
    type hierarchy. If the data type attribute points ``Number``, then the type
    of the value attribute may still be ``UInt32``, but also ``Float`` or
    ``Byte``.

    Consistency between the data type attribute in the variable and its
    `VariableTypeNode` is ensured.

    Value Rank


    This attribute indicates whether the value attribute of the variable is an
    array and how many dimensions the array has. It may have the following
    values:

    - ``n >= 1``: the value is an array with the specified number of dimensions
    - ``n =  0``: the value is an array with one or more dimensions
    - ``n = -1``: the value is a scalar
    - ``n = -2``: the value can be a scalar or an array with any number of dimensions
    - ``n = -3``: the value can be a scalar or a one dimensional array

    Consistency between the value rank attribute in the variable and its
    `variabletypenode` is ensured.

    TODO:
    Array Dimensions

    If the value rank permits the value to be a (multi-dimensional) array, the
    exact length in each dimensions can be further constrained with this
    attribute.

    - For positive lengths, the variable value is guaranteed to be of the same
      length in this dimension.
    - The dimension length zero is a wildcard and the actual value may have any
      length in this dimension.

    Consistency between the array dimensions attribute in the variable and its
    `variabletypenode` is ensured.

    Indicates whether a variable contains data inline or whether it points to an
    external data source.
  """

  @enforce_keys [:args]

  defstruct basic_nodes_attrs() ++ [:data_type, :value_rank, :array_dimensions, :array, :value, :access_level, :minimum_sampling_interval, :historizing]

  @doc """

  """
  @spec new(term(), list()) :: %__MODULE__{}
  def new(args, attrs \\ []) when is_list(args) do
    Keyword.fetch!(args, :requested_new_node_id)
    Keyword.fetch!(args, :parent_node_id)
    Keyword.fetch!(args, :reference_type_node_id)
    Keyword.fetch!(args, :browse_name)
    Keyword.fetch!(args, :type_definition)

    struct(%__MODULE__{args: args}, attrs)
  end
end

defmodule OpcUA.VariableTypeNode do
  use IsEnumerable
  use IsAccessible

  import OpcUA.BaseNodeAttrs

  @moduledoc """
    VariableTypeNode

    VariableTypes are used to provide type definitions for variables.
    VariableTypes constrain the data type, value rank and array dimensions
    attributes of variable instances. Furthermore, instantiating from a specific
    variable type may provide semantic information. For example, an instance from
    `MotorTemperatureVariableType` is more meaningful than a float variable
    instantiated from `BaseDataVariable`.

  """

  @enforce_keys [:args]

  defstruct basic_nodes_attrs() ++ [:data_type, :value_rank, :value, :access_level, :minimum_sampling_interval, :historizing]

  @doc """

  """
  @spec new(term(), list()) :: %__MODULE__{}
  def new(args, attrs \\ []) when is_list(args) do
    Keyword.fetch!(args, :requested_new_node_id)
    Keyword.fetch!(args, :parent_node_id)
    Keyword.fetch!(args, :reference_type_node_id)
    Keyword.fetch!(args, :browse_name)
    Keyword.fetch!(args, :type_definition)

    struct(%__MODULE__{args: args}, attrs)
  end
end

#TODO: add Method Node backend.
defmodule OpcUA.MethodNode do
  use IsEnumerable
  use IsAccessible

  import OpcUA.BaseNodeAttrs

  @moduledoc """
    MethodNode

    Methods define callable functions and are invoked using the :ref:`Call
    <method-services>` service. MethodNodes may have special properties (variable
    childen with a ``hasProperty`` reference) with the :ref:`qualifiedname` ``(0,
    "InputArguments")`` and ``(0, "OutputArguments")``. The input and output
    arguments are both described via an array of ``UA_Argument``. While the Call
    service uses a generic array of :ref:`variant` for input and output, the
    actual argument values are checked to match the signature of the MethodNode.

    Note that the same MethodNode may be referenced from several objects (and
    object types). For this, the NodeId of the method *and of the object
    providing context* is part of a Call request message.

  """

  @enforce_keys [:args]

  defstruct basic_nodes_attrs() ++ [:executable]

  @doc """

  """
  @spec new(term(), list()) :: %__MODULE__{}
  def new(args, attrs \\ []) when is_list(args) do
    Keyword.fetch!(args, :requested_new_node_id)
    Keyword.fetch!(args, :parent_node_id)
    Keyword.fetch!(args, :reference_type_node_id)
    Keyword.fetch!(args, :browse_name)
    Keyword.fetch!(args, :type_definition)

    struct(%__MODULE__{args: args}, attrs)
  end
end

#TODO: eventNotifier backend
defmodule OpcUA.ObjectNode do
  use IsEnumerable
  use IsAccessible

  import OpcUA.BaseNodeAttrs

  @moduledoc """
    ObjectNode

    Objects are used to represent systems, system components, real-world objects
    and software objects. Objects are instances of an `object
    type<objecttypenode>` and may contain variables, methods and further
    objects.
  """

  @enforce_keys [:args]

  defstruct basic_nodes_attrs() ++ [:event_notifier]

  @doc """

  """
  @spec new(term(), list()) :: %__MODULE__{}
  def new(args, attrs \\ []) when is_list(args) do
    Keyword.fetch!(args, :requested_new_node_id)
    Keyword.fetch!(args, :parent_node_id)
    Keyword.fetch!(args, :reference_type_node_id)
    Keyword.fetch!(args, :browse_name)
    Keyword.fetch!(args, :type_definition)

    struct(%__MODULE__{args: args}, attrs)
  end
end

defmodule OpcUA.ObjectTypeNode do
  use IsEnumerable
  use IsAccessible

  import OpcUA.BaseNodeAttrs

  @moduledoc """
    ObjectTypeNode

    ObjectTypes provide definitions for Objects. Abstract objects cannot be
    instantiated.
  """

  @enforce_keys [:args]

  defstruct basic_nodes_attrs() ++ [:is_abstract]

  @doc """

  """
  @spec new(term(), list()) :: %__MODULE__{}
  def new(args, attrs \\ []) when is_list(args) do
    Keyword.fetch!(args, :requested_new_node_id)
    Keyword.fetch!(args, :parent_node_id)
    Keyword.fetch!(args, :reference_type_node_id)
    Keyword.fetch!(args, :browse_name)

    struct(%__MODULE__{args: args}, attrs)
  end
end

#TODO: symmetric backend
defmodule OpcUA.ReferenceTypeNode do
  use IsEnumerable
  use IsAccessible

  import OpcUA.BaseNodeAttrs

  @moduledoc """
    ReferenceTypeNode

    Each reference between two nodes is typed with a ReferenceType that gives
    meaning to the relation. The OPC UA standard defines a set of ReferenceTypes
    as a mandatory part of OPC UA information models.

    - Abstract ReferenceTypes cannot be used in actual references and are only
      used to structure the ReferenceTypes hierarchy
    - Symmetric references have the same meaning from the perspective of the
      source and target node
  """

  @enforce_keys [:args]

  defstruct basic_nodes_attrs() ++ [:is_abstract, :symmetric, :inverse_name]

  @doc """

  """
  @spec new(term(), list()) :: %__MODULE__{}
  def new(args, attrs \\ []) when is_list(args) do
    Keyword.fetch!(args, :requested_new_node_id)
    Keyword.fetch!(args, :parent_node_id)
    Keyword.fetch!(args, :reference_type_node_id)
    Keyword.fetch!(args, :browse_name)

    struct(%__MODULE__{args: args}, attrs)
  end
end

defmodule OpcUA.DataTypeNode do
  use IsEnumerable
  use IsAccessible

  import OpcUA.BaseNodeAttrs

  @moduledoc """
    DataTypeNode

    DataTypes represent simple and structured data types. DataTypes may contain
    arrays. But they always describe the structure of a single instance. In
    open62541, DataTypeNodes in the information model hierarchy are matched to
    ``UA_DataType`` type descriptions for :ref:`generic-types` via their NodeId.

    Abstract DataTypes (e.g. ``Number``) cannot be the type of actual values.
    They are used to constrain values to possible child DataTypes (e.g.
    ``UInt32``).
  """

  @enforce_keys [:args]

  defstruct basic_nodes_attrs() ++ [:is_abstract]

  @doc """

  """
  @spec new(term(), list()) :: %__MODULE__{}
  def new(args, attrs \\ []) when is_list(args) do
    Keyword.fetch!(args, :requested_new_node_id)
    Keyword.fetch!(args, :parent_node_id)
    Keyword.fetch!(args, :reference_type_node_id)
    Keyword.fetch!(args, :browse_name)

    struct(%__MODULE__{args: args}, attrs)
  end
end

defmodule OpcUA.ViewNode do
  use IsEnumerable
  use IsAccessible

  import OpcUA.BaseNodeAttrs

  @moduledoc """
    ViewNode

    Each View defines a subset of the Nodes in the AddressSpace. Views can be
    used when browsing an information model to focus on a subset of nodes and
    references only. ViewNodes can be created and be interacted with. But their
    use in the :ref:`Browse<view-services>` service is currently unsupported in
    open62541.
  """

  @enforce_keys [:args]

  defstruct basic_nodes_attrs() ++ [:event_notifier]

  @doc """

  """
  @spec new(term(), list()) :: %__MODULE__{}
  def new(args, attrs \\ []) when is_list(args) do
    Keyword.fetch!(args, :requested_new_node_id)
    Keyword.fetch!(args, :parent_node_id)
    Keyword.fetch!(args, :reference_type_node_id)
    Keyword.fetch!(args, :browse_name)

    struct(%__MODULE__{args: args}, attrs)
  end
end

defmodule OpcUA.ReferenceNode do
  use IsEnumerable
  use IsAccessible

  import OpcUA.BaseNodeAttrs

  @moduledoc """

  """

  @enforce_keys [:args]

  defstruct basic_nodes_attrs() ++ [:is_abstract, :symmetric, :inverse_name]

  @doc """

  """
  @spec new(term(), list()) :: %__MODULE__{}
  def new(args, attrs \\ []) when is_list(args) do
    Keyword.fetch!(args, :source_id)
    Keyword.fetch!(args, :reference_type_id)
    Keyword.fetch!(args, :target_id)
    Keyword.fetch!(args, :is_forward)

    struct(%__MODULE__{args: args}, attrs)
  end
end
