defmodule Zappa.Sendgrid.BlockHelpers.If do
  @moduledoc false
  # This module implements the [if](https://handlebarsjs.com/guide/builtin-helpers.html#if) block-helper.
  # This helper must include options.

  alias Zappa.Tag

  import Zappa.Sendgrid.Variable, only: [from_options_arg: 1]

  def parse(%Tag{raw_options: ""}) do
    {:error, "The if helper requires options, e.g. {{#if options}}"}
  end

  def parse(tag) do
    {
      :ok,
      # always fallback to nil for similating if...else semantics
      """
      <%= cond do %>
      <% #{from_options_arg(hd(tag.args))} -> %>#{tag.block_contents}<% true -> %><% nil %>
      <% end %>
      """
    }
  end
end
