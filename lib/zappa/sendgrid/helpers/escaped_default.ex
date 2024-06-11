defmodule Zappa.Sendgrid.Helpers.EscapedDefault do
  @moduledoc false
  # This is the default helper used for escaped tags, used to render simple `{{tags}}`.

  import Zappa.Sendgrid.Variable, only: [from_tag_name: 1]

  def parse(%Zappa.Tag{} = tag) do
    with %Zappa.Tag{name: tag_name} when tag.raw_options == "" <- tag,
         {:ok, var_name} <- from_tag_name(tag_name) do
      {:ok, "<%= #{var_name} %>"}
    else
      _ -> Zappa.Helpers.EscapedDefault.parse(tag)
    end
  end
end
