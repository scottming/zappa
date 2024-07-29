defmodule Zappa.Sendgrid.Helpers.Insert do
  @moduledoc """
  This module implements the `insert` helper.
  https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#insert
  """

  alias Zappa.Tag
  import Zappa.Sendgrid.Variable, only: [from_options_arg: 1]

  def parse(%Tag{} = tag) do
    if length(tag.args) == 2 do
      [var_arg, default_arg] = tag.args
      default_arg = default_value(default_arg)
      output = "<%= #{from_options_arg(var_arg)} || #{from_options_arg(default_arg)} %>"

      {:ok, output}
    else
      {:error, "insert block-helper requires exactly two arguments"}
    end
  end

  defp default_value(%{value: value} = arg) do
    default = String.split(value, "default=", parts: 2) |> List.last()
    %{arg | value: default}
  end
end
