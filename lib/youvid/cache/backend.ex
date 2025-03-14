defmodule Youvid.Cache.Backend do
  @moduledoc """
  Behaviour for implementing cache backends for Youvid.

  This module defines the interface that all cache backends must implement.
  Different storage mechanisms (memory, disk, S3) can be used by implementing this behaviour.
  """

  # Type definitions for cache backend

  @type key :: String.t()
  @type value :: any()
  @type ttl :: integer()
  @type backend_options :: keyword()

  @doc """
  Initialize the cache backend with the given options.
  """
  @callback init(backend_options()) :: {:ok, term()} | {:error, term()}

  @doc """
  Store a value in the cache with a given key and TTL.
  """
  @callback put(key(), value(), ttl(), term()) :: :ok | {:error, term()}

  @doc """
  Retrieve a value from the cache by key.
  Returns the stored value if found, nil if the key is not found or if the entry has expired.
  The stored value is returned as-is, without wrapping in an {:ok, value} tuple.
  """
  @callback get(key(), term()) :: value() | nil | {:error, term()}

  @doc """
  Delete an entry from the cache by key.
  """
  @callback delete(key(), term()) :: :ok | {:error, term()}

  @doc """
  Clear all entries from the cache.
  """
  @callback clear(term()) :: :ok | {:error, term()}

  @doc """
  Clean up expired entries from the cache.
  """
  @callback cleanup(term()) :: :ok | {:error, term()}
end
