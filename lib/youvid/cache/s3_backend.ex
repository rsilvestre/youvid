defmodule Youvid.Cache.S3Backend do
  @moduledoc """
  Amazon S3 cache backend implementation.

  This backend stores cache entries in Amazon S3, making them persistent and shareable
  across multiple application instances. Requires the ex_aws and ex_aws_s3 packages.

  To use this backend, you must have the following dependencies installed:
  - ex_aws
  - ex_aws_s3
  - sweet_xml
  - configparser_ex (optional, for reading AWS credentials from files)

  ## Configuration

  The S3Backend supports the following options:

  * `:bucket` - S3 bucket name (defaults to "youvid-cache")
  * `:prefix` - Prefix for cache objects in the bucket (defaults to "cache")
  * `:region` - AWS region (defaults to "us-east-1")
  """

  @behaviour Youvid.Cache.Backend

  @default_bucket "youvid-cache"
  @default_prefix "cache"
  @default_region "us-east-1"
  @registry_file "registry.bin"

  @options_schema [
    bucket: [
      type: :string,
      default: @default_bucket,
      doc: "S3 bucket name for storing cache objects"
    ],
    prefix: [
      type: :string,
      default: @default_prefix,
      doc: "Prefix for cache objects in the bucket"
    ],
    region: [
      type: :string,
      default: @default_region,
      doc: "AWS region for the S3 bucket"
    ]
  ]

  # Backend Implementation

  @impl true
  def init(options) do
    with {:ok, _} <- ensure_dependencies_loaded(),
         {:ok, validated_options} <- NimbleOptions.validate(options, @options_schema) do

      bucket = validated_options[:bucket]
      prefix = validated_options[:prefix]
      region = validated_options[:region]

      # Load the registry if it exists
      registry = load_registry(bucket, prefix)

      {:ok,
       %{
         bucket: bucket,
         prefix: prefix,
         region: region,
         registry: registry
       }}
    else
      {:error, %NimbleOptions.ValidationError{} = error} ->
        {:error, Exception.message(error)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def put(key, value, ttl, state) do
    now = System.system_time(:millisecond)
    expiry = now + ttl

    # Update registry with new expiry
    registry = Map.put(state.registry, key, expiry)

    # Save the value to S3
    with :ok <- save_value(key, value, state),
         :ok <- save_registry(registry, state) do
      {:ok, %{state | registry: registry}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get(key, state) do
    now = System.system_time(:millisecond)

    case Map.get(state.registry, key) do
      nil ->
        nil

      expiry when expiry < now ->
        # Expired, remove from registry and delete from S3
        registry = Map.delete(state.registry, key)
        delete_value(key, state)
        save_registry(registry, state)
        nil

      _expiry ->
        # Valid entry, get from S3
        case get_value(key, state) do
          {:ok, value} -> value
          _error -> nil
        end
    end
  end

  @impl true
  def delete(key, state) do
    registry = Map.delete(state.registry, key)
    delete_value(key, state)
    save_registry(registry, state)
    :ok
  end

  @impl true
  def clear(state) do
    # Delete all objects with the prefix
    list_objects(state)
    |> Enum.each(fn key ->
      delete_value(key, state)
    end)

    # Clear registry
    save_registry(%{}, state)
    :ok
  end

  @impl true
  def cleanup(state) do
    now = System.system_time(:millisecond)

    # Filter out expired entries
    {expired_keys, valid_entries} =
      Enum.split_with(state.registry, fn {_key, expiry} -> expiry < now end)

    # Delete expired objects from S3
    Enum.each(expired_keys, fn {key, _} ->
      delete_value(key, state)
    end)

    # Update registry
    registry = Map.new(valid_entries)
    save_registry(registry, state)

    :ok
  end

  # Helper functions

  defp ensure_dependencies_loaded do
    deps = [
      {:ex_aws, "ExAws"},
      {:ex_aws_s3, "ExAws.S3"},
      {:sweet_xml, "SweetXml"}
    ]

    Enum.find(deps, {:ok, nil}, fn {app, module_name} ->
      module = String.to_atom("Elixir.#{module_name}")

      case Code.ensure_loaded(module) do
        # Continue checking
        {:module, _} -> false
        {:error, _} -> {:error, {:missing_dependency, app}}
      end
    end)
  end

  defp s3_key(key, state) do
    Path.join([state.prefix, to_string(key)])
  end

  defp registry_key(state) do
    Path.join([state.prefix, @registry_file])
  end

  defp load_registry(bucket, prefix) do
    state = %{bucket: bucket, prefix: prefix}

    case get_object(registry_key(state), state) do
      {:ok, binary} when is_binary(binary) ->
        try do
          :erlang.binary_to_term(binary)
        rescue
          _ -> %{}
        end

      _error ->
        %{}
    end
  end

  defp save_registry(registry, state) do
    binary = :erlang.term_to_binary(registry)
    put_object(registry_key(state), binary, state)
  end

  defp save_value(key, value, state) do
    binary = :erlang.term_to_binary(value)
    put_object(s3_key(key, state), binary, state)
  end

  defp get_value(key, state) do
    case get_object(s3_key(key, state), state) do
      {:ok, binary} when is_binary(binary) ->
        try do
          {:ok, :erlang.binary_to_term(binary)}
        rescue
          _ -> {:error, :deserialize_failed}
        end

      error ->
        error
    end
  end

  defp delete_value(key, state) do
    delete_object(s3_key(key, state), state)
  end

  # S3 operations

  defp get_object(key, state) do
    ExAws.S3.get_object(state.bucket, key)
    |> ExAws.request(region: state.region)
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, {:http_error, 404, _}} -> {:error, :not_found}
      error -> error
    end
  end

  defp put_object(key, body, state) do
    ExAws.S3.put_object(state.bucket, key, body)
    |> ExAws.request(region: state.region)
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp delete_object(key, state) do
    ExAws.S3.delete_object(state.bucket, key)
    |> ExAws.request(region: state.region)
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp list_objects(state) do
    ExAws.S3.list_objects(state.bucket, prefix: state.prefix)
    |> ExAws.request(region: state.region)
    |> case do
      {:ok, %{body: %{contents: contents}}} ->
        Enum.map(contents, fn %{key: key} -> key end)

      _error ->
        []
    end
  end
end
