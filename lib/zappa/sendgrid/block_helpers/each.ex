defmodule Zappa.Sendgrid.BlockHelpers.Each do
  @moduledoc """
  https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#iterations
  """
  alias Zappa.Tag
  import Zappa.Sendgrid.Variable, only: [from_options_arg: 1]

  def parse(%Tag{args: []}) do
    {:error, "The each helper requires options, e.g. {{#each options}}"}
  end

  def parse(%Tag{args: args}) when length(args) != 1 do
    {:error, "The equals block helper requires one options, e.g. {{#each var1}}"}
  end

  def parse(%Tag{args: [collection], block_contents: block_contents}) do
    """
    <%= for this <- #{from_options_arg(collection)} do %>
      #{block_contents}
    <% end %>
    """
  end
end
