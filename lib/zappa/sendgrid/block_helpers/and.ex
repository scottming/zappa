defmodule Zappa.Sendgrid.BlockHelpers.And do
  @moduledoc """
  https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#and
  """

  alias Zappa.Tag
  import Zappa.Sendgrid.Variable, only: [from_options_arg: 1]

  def parse(%Tag{raw_options: ""}) do
    {:error, "The equals block helper requires two options, e.g. {{#and var1 var2}}"}
  end

  def parse(%Tag{args: args}) when length(args) != 2 do
    {:error, "The equals block helper requires two options, e.g. {{#and var1 var2}}"}
  end

  def parse(%Tag{args: [arg1, arg2], block_contents: block_contents}) do
    {
      :ok,
      """
      <%= cond do %>
      <% #{from_options_arg(arg1)} && #{from_options_arg(arg2)} -> %>#{block_contents}<% true -> %><% nil %>
      <% end %>
      """
    }
  end
end
