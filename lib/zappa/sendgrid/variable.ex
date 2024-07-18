defmodule Zappa.Sendgrid.Variable do
  @moduledoc false

  # this is a special variable referenced in each block helper
  def from_tag_name("this"), do: {:ok, "this"}
  def from_tag_name(tag_name), do: {:ok, "@#{normalize(tag_name)}"}

  def from_options_arg(%{value: value, quoted?: quoted?}) do
    if quoted? do
      ~s|"#{value}"|
    else
      "@#{normalize(value)}"
    end
  end

  defp normalize(name), do: String.trim(name, "@root.")
end
