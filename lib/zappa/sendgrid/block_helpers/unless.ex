defmodule Zappa.Sendgrid.BlockHelpers.Unless do
  @moduledoc false
  # This module implements the `unless` block-helper.
  # https://handlebarsjs.com/guide/builtin-helpers.html#unless

  alias Zappa.Tag
  import Zappa.Sendgrid.Variable, only: [from_options_arg: 1]

  def parse(%Tag{} = tag) do
    output = """
    <%= cond do %>
    <% !#{from_options_arg(hd(tag.args))} -> %>#{tag.block_contents}<% end %>
    """

    {:ok, output}
  end
end
