defmodule Zappa.Sendgrid.Helpers.ElseIf do
  @moduledoc false

  alias Zappa.Tag
  import Zappa.Sendgrid.Variable, only: [from_options_arg: 1]

  def parse(%Tag{raw_options: ""}) do
    {:error, "The else if requires options, e.g. {{#if options}}"}
  end

  def parse(tag) do
    {:ok, "<% #{from_options_arg(hd(tag.args))} -> %>#{tag.block_contents}\n"}
  end
end
