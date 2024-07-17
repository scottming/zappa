defmodule Zappa.Sendgrid.Helpers.ElseGreaterThan do
  @moduledoc false

  alias Zappa.Tag
  import Zappa.Sendgrid.Variable, only: [from_options_arg: 1]

  def parse(%Tag{raw_options: ""}) do
    {:error,
     "The else greaterThan helper requires two options, e.g. {{else greaterThan var1 var2}}"}
  end

  def parse(%Tag{args: args}) when length(args) != 2 do
    {:error,
     "The else greaterThan helper requires two options, e.g. {{else greaterThan var1 var2}}"}
  end

  def parse(%Tag{args: [arg1, arg2], block_contents: block_contents}) do
    {:ok, "<% #{from_options_arg(arg1)} > #{from_options_arg(arg2)} -> %>#{block_contents}\n"}
  end
end
