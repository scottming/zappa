defmodule Zappa.Sendgrid.Variable do
  @moduledoc false

  # this is a special variable referenced in each block helper
  def from_tag_name("this" <> _ = var), do: {:ok, normalize(var, "")}
  def from_tag_name(tag_name), do: {:ok, normalize(tag_name, "@")}

  def from_options_arg(%{value: value, quoted?: quoted?}) do
    if quoted? do
      ~s|"#{value}"|
    else
      case value do
        "this" <> _ = var -> normalize(var, "")
        _ -> normalize(value, "@")
      end
    end
  end

  defp normalize(var_name, prefix) do
    trimmed_var_name = String.trim(var_name, "@root.")

    case String.split(trimmed_var_name, ".") do
      [root] ->
        "#{prefix}#{root}"

      [root | keys] ->
        path = Enum.map_join(keys, ", ", &":#{&1}")
        "get_in(#{prefix}#{root}, [#{path}])"
    end
  end
end
