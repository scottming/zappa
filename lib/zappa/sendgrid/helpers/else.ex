defmodule Zappa.Sendgrid.Helpers.Else do
  @moduledoc false
  # This module implements the `else` helper function. This clause may be used inside of block-helpers.

  alias Zappa.Tag

  def parse(%Tag{raw_options: ""}) do
    {:ok, "<% true -> %>"}
  end

  def parse(_tag) do
    {:error, "{{else}} tag does not allow options."}
  end
end
