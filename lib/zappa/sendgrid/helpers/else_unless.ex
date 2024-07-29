defmodule Zappa.Sendgrid.Helpers.ElseUnless do
  @moduledoc false

  alias Zappa.Tag
  import Zappa.Sendgrid.Variable, only: [from_options_arg: 1]

  def parse(%Tag{raw_options: ""}) do
    {:error, "The else unless helper requires two options, e.g. {{else unless var1}}"}
  end

  def parse(%Tag{args: args}) when length(args) != 1 do
    {:error, "The else or helper requires two options, e.g. {{else or var1}}"}
  end

  def parse(%Tag{args: [arg], block_contents: block_contents}) do
    {:ok, "<% !#{from_options_arg(arg)} -> %>#{block_contents}\n"}
  end
end
