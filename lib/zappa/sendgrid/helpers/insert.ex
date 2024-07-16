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
      output = "<%= #{from_options_arg(var_arg)} or #{from_options_arg(default_arg)} %>"
      {:ok, output}
    else
      {:error, "insert block-helper requires exactly two arguments"}
    end
  end
end
