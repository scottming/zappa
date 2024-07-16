defmodule Zappa.Sendgrid do
  @moduledoc """
  Sendgrid Favored Handlerbars
  """

  @default_escaped_callback &Zappa.Sendgrid.Helpers.EscapedDefault.parse/1
  @default_unescaped_callback &Zappa.Sendgrid.Helpers.UnescapedDefault.parse/1

  @default_helpers %Zappa.Helpers{
    helpers: %{
      "else if" => &Zappa.Sendgrid.Helpers.ElseIf.parse/1,
      "else" => &Zappa.Sendgrid.Helpers.Else.parse/1,
      "log" => &Zappa.Helpers.Log.parse/1,
      "__escaped__" => @default_escaped_callback,
      "__unescaped__" => @default_unescaped_callback,
      "@index" => &Zappa.Helpers.Index.parse/1,
      "@key" => &Zappa.Helpers.Key.parse/1,
      "insert" => &Zappa.Sendgrid.Helpers.Insert.parse/1
    },
    block_helpers: %{
      "if" => &Zappa.Sendgrid.BlockHelpers.If.parse/1,
      "each" => &Zappa.BlockHelpers.Each.parse/1,
      "foreach" => &Zappa.BlockHelpers.ForEach.parse/1,
      "raw" => &Zappa.BlockHelpers.Raw.parse/1,
      "unless" => &Zappa.Sendgrid.BlockHelpers.Unless.parse/1,
      "equals" => &Zappa.BlockHelpers.Equals.parse/1
    },
    partials: %{}
  }

  @spec compile(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def compile(handlebars_template) do
    Zappa.compile(handlebars_template, @default_helpers)
  end
end
