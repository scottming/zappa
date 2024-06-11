defmodule Zappa do
  @moduledoc """
  This is the main module for interfacing with Zappa and your Handlebars templates. Use `Zappa.compile/1` or
  `Zappa.compile/2` to compile your Handlebars templates into EEx templates.

  This implementation relies on tail recursion and not regular expressions.
  ```
  """
  alias Zappa.{
    Helpers,
    OptionParser,
    Tag
  }

  require Logger

  # Denotes a string used to collect
  @typep accumulator :: String.t()

  # A list where the first item represents the block that is in context. This is used as the parser traverses into
  # nested blocks, e.g. {{if something}}{{if something_else}}some text{{/if}}{{/if}}
  # It affects the validation of the closing tag (e.g. {{/if}}): a closing tag is only valid if it closes the current
  # block context
  @typep block_contexts :: list()

  # A string denoting the beginning or end of a tag, e.g. }}
  @typep delimiter :: String.t()

  @typep eex_template :: String.t()
  # A [Handlebars.js](https://handlebarsjs.com/) template (as a string). [Try it](http://tryhandlebarsjs.com/)!
  @typep handlebars_template :: String.t()

  # The string being parsed, from the active point to the end.
  @typep head :: String.t()
  # The rest of the string
  @typep tail :: String.t()

  # These are defined separately because the parser will fall back to them if no callbacks are registered in the
  # %Zappa.Helpers{} struct: they are required for sensible operation.
  @default_escaped_callback &Zappa.Helpers.EscapedDefault.parse/1
  @default_unescaped_callback &Zappa.Helpers.UnescapedDefault.parse/1

  @default_helpers %Zappa.Helpers{
    helpers: %{
      "else" => &Zappa.Helpers.Else.parse/1,
      "log" => &Zappa.Helpers.Log.parse/1,
      "__escaped__" => @default_escaped_callback,
      "__unescaped__" => @default_unescaped_callback,
      "@index" => &Zappa.Helpers.Index.parse/1,
      "@key" => &Zappa.Helpers.Key.parse/1
    },
    block_helpers: %{
      "if" => &Zappa.BlockHelpers.If.parse/1,
      "each" => &Zappa.BlockHelpers.Each.parse/1,
      "foreach" => &Zappa.BlockHelpers.ForEach.parse/1,
      "raw" => &Zappa.BlockHelpers.Raw.parse/1,
      "unless" => &Zappa.BlockHelpers.Unless.parse/1
    },
    partials: %{}
  }

  # The regular expression used to detect if a supplied template contains any EEx expressions
  @eex_regex ~r/<%.*%>/U

  @doc """
  Compiles a handlebars template to an EEx string using the default helpers (if, with, unless, etc.).
  See `Zappa.get_default_helpers/0`

  ## Examples

      iex> handlebars_template = "Hello {{{thing}}}"
      iex> Zappa.compile(handlebars_template)
      {:ok, "Hello <%= thing %>"}

  """
  @spec compile(handlebars_template) :: {:ok, eex_template} | {:error, String.t()}
  def compile(template), do: compile(template, get_default_helpers())

  @doc """
  Compiles a handlebars template to EEx using the helpers provided.  This is the function you want if you want to add
  your own helper functions to the processing.
  """
  @spec compile(handlebars_template, Helpers.t()) ::
          {:ok, eex_template} | {:error, String.t()}
  def compile(template, %Zappa.Helpers{} = helpers) do
    case has_eex?(template) do
      true ->
        {:error, "Compilation unsafe: the source template contains EEx expressions."}

      false ->
        helper_parsing_regex = build_helper_parsing_regex(helpers)
        parse(template, "", helpers, [], helper_parsing_regex)
    end
  end

  @doc """
  This is a variant of the `Zappa.compile/1` function that raises an error instead of returning a tuple.  (I was
  told this was idiomatic Elixir).
  """
  @spec compile!(handlebars_template) :: eex_template
  def compile!(template) do
    compile(template, get_default_helpers())
    |> bangify()
  end

  @doc """
  This is a variant of the `Zappa.compile/2` function that raises an error instead of returning a tuple.
  """
  @spec compile!(handlebars_template, Helpers.t()) :: eex_template
  def compile!(template, %Zappa.Helpers{} = helpers) do
    compile(template, helpers)
    |> bangify()
  end

  @doc """
  Retrieves the regular-, block-, and partial-helpers registered by default.  This function is a useful starting place
  when you wish to add your own helpers to the defaults.

  ## Examples
      iex> helpers = Zappa.get_default_helpers()
      iex> helpers = Zappa.register_helper("random_number", fn(tag) -> 42 end)
      iex> {:ok, eex} = Zappa.compile("My favorite number is {{random_number}}", helpers)

  See the following functions for easily adding your own callbacks into the `%Zappa.Helpers{}` struct:
  - `Zappa.register_helper/3`
  - `Zappa.register_block/3`
  - `Zappa.register_partial/3`
  """
  @spec get_default_helpers() :: Helpers.t()
  def get_default_helpers, do: @default_helpers

  @doc """
  This is a convenience function that adds your helper callback to the `%Zappa.Helpers{}` struct.
  The callback function provided should take one argument representing the options included with the tag.

  ## Examples
      iex> helpers = Zappa.get_default_helpers()
        |> Zappa.register_helper("random_track", fn(_tag) ->
          Enum.random(["Willie the Pimp", "Little Umbrellas", "Son of Mr. Green Genes"])
        end)
        |> Zappa.compile("<p>For your listening enjoyment: {{random_track}}</p>", helpers)

  """
  # See https://elixirforum.com/t/using-put-in-for-structs/27645
  @spec register_helper(Helpers.t(), String.t(), function) :: Helpers.t()
  def register_helper(%Helpers{} = helpers, name, callback) do
    validate_callback_name(name)
    put_in(helpers.helpers[name], callback)
  end

  @doc """
  This is a convenience function that adds your block helper callback to the %Zappa.Helpers{} struct.
  """
  @spec register_block(Helpers.t(), String.t(), function) :: Helpers.t()
  def register_block(%Helpers{} = helpers, name, callback) do
    validate_callback_name(name)
    put_in(helpers.block_helpers[name], callback)
  end

  @doc """
  This is a convenience function that adds your helper callback to the %Zappa.Helpers{} struct.
  """
  @spec register_partial(Helpers.t(), String.t(), function) :: Helpers.t()
  def register_partial(%Helpers{} = helpers, name, callback) do
    validate_callback_name(name)
    put_in(helpers.partials[name], callback)
  end

  ######################################################################################################################
  # Find a raw block
  defp accumulate_block_content("{{{{/" <> tail, tag_name, acc, helper_parsing_regex) do
    with {:ok, tag, tail} <- accumulate_tag(tail, "}}}}", "", ["{"], helper_parsing_regex),
         tag <- %Tag{tag | opening_delimiter: "{{{{/"},
         :ok <- validate_closing_raw_block_tag(tag, tag_name) do
      {:ok, acc, tail}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp accumulate_block_content(<<head::binary-size(1), tail::binary>>, tag_name, acc, helpers) do
    accumulate_block_content(tail, tag_name, acc <> head, helpers)
  end

  ######################################################################################################################
  # This block is devoted to finding the tag and returning data about it (as a %Tag{} struct)
  ######################################################################################################################
  @spec accumulate_tag(head, delimiter, accumulator, list, Regex.t()) ::
          {:error, String.t()} | {:ok, %Tag{}, tail}
  defp accumulate_tag(head, closing_delimiter, tag_acc, forbidden_chars, helper_parsing_regex)

  defp accumulate_tag("", _ending_delimiter, _tag_acc, _forbidden_chars, _helpers),
    do: {:error, "Unclosed tag."}

  # We found the 4-char closing delimiter we were looking for
  @spec accumulate_tag(head, delimiter, accumulator, list, Regex.t()) ::
          {:error, String.t()} | {:ok, %Tag{}, tail}
  defp accumulate_tag(
         <<h::binary-size(4), tail::binary>>,
         closing_delimiter,
         tag_acc,
         _forbidden_chars,
         helper_parsing_regex
       )
       when closing_delimiter == h do
    make_tag_struct(tag_acc, tail, closing_delimiter, helper_parsing_regex)
  end

  # We found the 3-char closing delimiter we were looking for
  defp accumulate_tag(
         <<h::binary-size(3), tail::binary>>,
         closing_delimiter,
         tag_acc,
         _forbidden_chars,
         helpers
       )
       when closing_delimiter == h do
    make_tag_struct(tag_acc, tail, closing_delimiter, helpers)
  end

  # We found the 2-char closing delimiter we were looking for
  defp accumulate_tag(
         <<h::binary-size(2), tail::binary>>,
         closing_delimiter,
         tag_acc,
         _forbidden_chars,
         helpers
       )
       when closing_delimiter == h do
    make_tag_struct(tag_acc, tail, closing_delimiter, helpers)
  end

  # Accumulate the character and continue...
  defp accumulate_tag(
         <<head::binary-size(1), tail::binary>>,
         closing_delimiter,
         tag_acc,
         forbidden_chars,
         helpers
       ) do
    # is this character forbidden within the tag?
    case Enum.member?(forbidden_chars, head) do
      true -> {:error, "Unexpected character #{head} inside a tag: #{tag_acc}"}
      false -> accumulate_tag(tail, closing_delimiter, tag_acc <> head, forbidden_chars, helpers)
    end
  end

  @spec bangify({atom, String.t()}) :: eex_template
  defp bangify(result) do
    case result do
      {:ok, eex} -> eex
      {:error, message} -> raise message
    end
  end

  @spec call_function(function, %Tag{}) :: {:ok, String.t()} | {:error, String.t()}
  defp call_function(callback, tag) do
    callback.(tag)
    |> handle_function_output()
  end

  @spec get_block_helper(Helpers.t(), String.t()) :: {:ok, function}
  defp get_block_helper(%Helpers{block_helpers: block_helpers}, name) do
    {
      :ok,
      Map.get(
        block_helpers,
        name,
        fn tag -> {:error, "Block-helper not registered: #{tag.name}"} end
      )
    }
  end

  # This getter is constructed so that one may override the default functionality, but it will always fall back to it.
  @spec get_helper(Helpers.t(), String.t()) :: {:ok, function}
  defp get_helper(%Helpers{helpers: helpers_map}, name) do
    {
      :ok,
      Map.get(
        helpers_map,
        name,
        Map.get(
          helpers_map,
          "__escaped__",
          @default_escaped_callback
        )
      )
    }
  end

  @spec get_partial_helper(Helpers.t(), String.t()) :: {:ok, function}
  defp get_partial_helper(%Helpers{partials: partial_helpers}, name) do
    handler =
      Map.get(
        partial_helpers,
        name,
        fn tag -> {:error, "Partial not registered: #{tag.name}"} end
      )

    # For convenience/normalization, we wrap the output in a function if only a string was registered
    case handler do
      handler when is_function(handler) -> {:ok, handler}
      handler -> {:ok, fn _ -> handler end}
    end
  end

  @spec get_unescaped_helper(Helpers.t()) :: {:ok, function}
  defp get_unescaped_helper(%Helpers{helpers: helpers_map}) do
    {
      :ok,
      Map.get(
        helpers_map,
        "__unescaped__",
        @default_unescaped_callback
      )
    }
  end

  # Because user-registered functions may return a simple string instead of a tuple
  @spec handle_function_output(any) :: {:ok, String.t()} | {:error, String.t()}
  defp handle_function_output(output) do
    case output do
      {:ok, output} ->
        {:ok, output}

      {:error, error} ->
        {:error, error}

      string when is_binary(string) ->
        {:ok, string}

      _ ->
        {
          :error,
          "Invalid function output. Helper function must return {:ok, String.t()} | {:error, String.t} | String.t"
        }
    end
  end

  # Detect if the given string contains EEx expressions
  @spec has_eex?(handlebars_template) :: boolean
  defp has_eex?(template), do: Regex.match?(@eex_regex, template)

  # https://elixirforum.com/t/how-to-detect-if-a-given-character-grapheme-is-whitespace/26735/5
  @spec make_tag_struct(accumulator, tail, delimiter, Regex.t()) ::
          {:error, String.t()} | {:ok, %Tag{}, tail}
  defp make_tag_struct(tag_acc, tail, closing_delimiter, helper_parsing_regex) do
    trimmed_tag_acc = String.trim(tag_acc)

    helper_parsed_result =
      helper_parsing_regex && Regex.named_captures(helper_parsing_regex, trimmed_tag_acc)

    result =
      if helper_parsed_result do
        [helper_parsed_result["tag_name"] | List.wrap(helper_parsed_result["tag_options"])]
      else
        # Splits when there is a {{simple}} tag vs. a tag {{with options}}
        String.split(trimmed_tag_acc, ~r/\p{Zs}/u, parts: 2)
      end

    case result do
      [tag_name] ->
        {
          :ok,
          %Tag{
            name: String.trim(tag_name),
            raw_contents: tag_acc,
            closing_delimiter: closing_delimiter
          },
          tail
        }

      [tag_name, tag_options] ->
        {args, kwargs} = OptionParser.split(tag_options)

        {
          :ok,
          %Tag{
            name: String.trim(tag_name),
            raw_options: String.trim(tag_options),
            args: args,
            kwargs: kwargs,
            raw_contents: tag_acc,
            closing_delimiter: closing_delimiter
          },
          tail
        }
    end
  end

  @spec parse(handlebars_template, accumulator, Helpers.t(), block_contexts, Regex.t()) ::
          {:ok, eex_template} | {:error, String.t()}
  defp parse(handlebars_template, accumulator, helpers, block_contexts, helper_parsing_regex)

  # TODO: {{{{raw-helper}}}}
  # End of handlebars template! All done!
  defp parse("", acc, _helpers, [], _), do: {:ok, acc}

  defp parse("", _acc, _helpers, [block | _], _) do
    {:error, "Unexpected end of template.  Closing block not found: {{/#{block}}}"}
  end

  ######################################################################################################################
  # Raw tags open
  defp parse(
         "{{{{" <> tail,
         acc,
         %Zappa.Helpers{} = helpers,
         block_contexts,
         helper_parsing_regex
       ) do
    with {:ok, tag, tail} <- accumulate_tag(tail, "}}}}", "", ["{"], helper_parsing_regex),
         tag <- %Tag{tag | opening_delimiter: "{{{{"},
         :ok <- validate_opening_block_tag(tag),
         {:ok, callback} <- get_block_helper(helpers, tag.name),
         {:ok, block_content, tail} <-
           accumulate_block_content(tail, tag.name, "", helper_parsing_regex),
         {:ok, content} <-
           call_function(callback, Map.put(tag, :block_contents, block_content)) do
      parse(tail, acc <> content, helpers, block_contexts, helper_parsing_regex)
    else
      {:error, error} -> {:error, error}
    end
  end

  ######################################################################################################################
  # Comment tag (long)
  defp parse(
         "{{!--" <> tail,
         acc,
         %Zappa.Helpers{} = helpers,
         block_contexts,
         helper_parsing_regex
       ) do
    case accumulate_tag(tail, "--}}", "", [], helper_parsing_regex) do
      {:ok, tag, tail} ->
        tag = %Tag{tag | opening_delimiter: "{{!--"}

        parse(
          tail,
          acc <> "<%##{tag.raw_contents}%>",
          helpers,
          block_contexts,
          helper_parsing_regex
        )

      {:error, message} ->
        {:error, message}
    end
  end

  ######################################################################################################################
  # Comment tag (short)
  defp parse("{{!" <> tail, acc, %Zappa.Helpers{} = helpers, block_contexts, helper_parsing_regex) do
    case accumulate_tag(tail, "}}", "", ["{"], helper_parsing_regex) do
      {:ok, tag, tail} ->
        tag = %Tag{tag | opening_delimiter: "{{!"}

        parse(
          tail,
          acc <> "<%##{tag.raw_contents}%>",
          helpers,
          block_contexts,
          helper_parsing_regex
        )

      {:error, message} ->
        {:error, message}
    end
  end

  ######################################################################################################################
  # Block open
  defp parse("{{#" <> tail, acc, %Zappa.Helpers{} = helpers, block_contexts, helper_parsing_regex) do
    with {:ok, tag, tail} <- accumulate_tag(tail, "}}", "", ["{"], helper_parsing_regex),
         tag <- %Tag{tag | opening_delimiter: "{{#"},
         :ok <- validate_opening_block_tag(tag),
         {:ok, callback} <- get_block_helper(helpers, tag.name),
         {:ok, block_content, tail, block_contexts} <-
           parse(tail, "", helpers, [tag.name | block_contexts], helper_parsing_regex),
         {:ok, content} <-
           call_function(callback, Map.put(tag, :block_contents, block_content)) do
      parse(tail, acc <> content, helpers, block_contexts, helper_parsing_regex)
    else
      {:error, error} -> {:error, error}
    end
  end

  ######################################################################################################################
  # Block close. Blocks must close the tag that opened.
  defp parse("{{/" <> _tail, _acc, _helpers, [], _) do
    {:error, "Unexpected closing block tag."}
  end

  defp parse("{{/" <> tail, acc, _helpers, [active_block | block_contexts], helper_parsing_regex) do
    with {:ok, tag, tail} <- accumulate_tag(tail, "}}", "", ["{"], helper_parsing_regex),
         tag <- %Tag{tag | opening_delimiter: "{{/"},
         :ok <- validate_closing_block_tag(tag, active_block) do
      {:ok, acc, tail, block_contexts}
    else
      {:error, error} -> {:error, error}
    end
  end

  ######################################################################################################################
  # Partial
  defp parse("{{>" <> tail, acc, %Zappa.Helpers{} = helpers, block_contexts, helper_parsing_regex) do
    with {:ok, tag, tail} <- accumulate_tag(tail, "}}", "", ["{"], helper_parsing_regex),
         tag <- %Tag{tag | opening_delimiter: "{{>"},
         :ok <- validate_partial_tag(tag),
         {:ok, callback} <- get_partial_helper(helpers, tag.name),
         {:ok, unparsed_content} <- call_function(callback, tag),
         {:ok, parsed_content} <-
           parse(unparsed_content, "", helpers, block_contexts, helper_parsing_regex) do
      parse(tail, acc <> parsed_content, helpers, block_contexts, helper_parsing_regex)
    else
      {:error, error} -> {:error, error}
    end
  end

  ######################################################################################################################
  # Non-escaped tag
  defp parse("{{{" <> tail, acc, %Zappa.Helpers{} = helpers, block_contexts, helper_parsing_regex) do
    with {:ok, tag, tail} <- accumulate_tag(tail, "}}}", "", ["{"], helper_parsing_regex),
         tag <- %Tag{tag | opening_delimiter: "{{{"},
         :ok <- validate_non_escaped_tag(tag),
         {:ok, function} <- get_unescaped_helper(helpers),
         {:ok, contents} <- call_function(function, tag) do
      parse(tail, acc <> contents, helpers, block_contexts, helper_parsing_regex)
    else
      {:error, error} -> {:error, error}
    end
  end

  ######################################################################################################################
  # Regular tag (HTML-escaped)
  defp parse("{{" <> tail, acc, %Zappa.Helpers{} = helpers, block_contexts, helper_parsing_regex) do
    with {:ok, tag, tail} <- accumulate_tag(tail, "}}", "", ["{"], helper_parsing_regex),
         tag <- %Tag{tag | opening_delimiter: "{{"},
         :ok <- validate_regular_tag(tag),
         {:ok, function} <- get_helper(helpers, tag.name),
         {:ok, contents} <- call_function(function, tag) do
      parse(tail, acc <> contents, helpers, block_contexts, helper_parsing_regex)
    else
      {:error, error} -> {:error, error}
    end
  end

  ######################################################################################################################
  # Error: ending delimiter found
  # Try to include some information in the error message
  defp parse("}}" <> _tail, acc, _helpers, _block_contexts, _helper_parsing_regex) do
    if String.length(acc) > 32 do
      <<first_chunk::binary-size(32)>> <> _ = acc
      {:error, "Unexpected closing delimiter: }}#{first_chunk}"}
    else
      {:error, "Unexpected closing delimiter: }}"}
    end
  end

  # Pass-thru: when we're not in a tag, the character at the head gets appended to the accumulator
  defp parse(
         <<head::binary-size(1)>> <> tail,
         acc,
         %Zappa.Helpers{} = helpers,
         block_contexts,
         helper_parsing_regex
       ),
       do: parse(tail, acc <> head, helpers, block_contexts, helper_parsing_regex)

  # Callback names cannot begin with a ".", but they can be things like "@index"
  defp validate_callback_name(name) when not is_binary(name) do
    raise "Invalid helper function name."
  end

  defp validate_callback_name(<<head::binary-size(1)>> <> _tail) when head in ["."] do
    raise "Invalid helper function name."
  end

  @spec validate_callback_name(String.t()) :: :ok
  defp validate_callback_name(_name), do: :ok

  @spec validate_closing_block_tag(%Tag{}, String.t()) :: {:error, String.t()}
  defp validate_closing_block_tag(%Tag{name: ""}, _active_block) do
    {:error, "Block closing tags require a name, e.g. {{/foo}}"}
  end

  @spec validate_closing_block_tag(%Tag{}, String.t()) :: {:error, String.t()} | :ok
  defp validate_closing_block_tag(tag, active_block) do
    if tag.name != active_block do
      {:error, "Unexpected closing block tag. Expected closing {{/#{active_block}}} tag."}
    else
      :ok
    end
  end

  @spec validate_closing_raw_block_tag(%Tag{}, String.t()) :: {:error, String.t()}
  defp validate_closing_raw_block_tag(%Tag{name: ""}, _active_block) do
    {:error, "Raw block closing tags require a name, e.g. {{{{/foo}}}}"}
  end

  @spec validate_closing_raw_block_tag(%Tag{}, String.t()) :: {:error, String.t()} | :ok
  defp validate_closing_raw_block_tag(tag, active_block) do
    if tag.name != active_block do
      {:error, "Unexpected closing block tag. Expected closing {{{{/#{active_block}}}}} tag."}
    else
      :ok
    end
  end

  @spec validate_non_escaped_tag(%Tag{}) :: {:error, String.t()}
  defp validate_non_escaped_tag(%Tag{name: ""}) do
    {:error, "Non-escaped tags require a name, e.g. {{{foo}}}"}
  end

  @spec validate_non_escaped_tag(%Tag{}) :: :ok
  defp validate_non_escaped_tag(%Tag{raw_options: ""}), do: :ok

  @spec validate_non_escaped_tag(%Tag{}) :: {:error, String.t()}
  defp validate_non_escaped_tag(_tag) do
    {:error, "Non-escaped tags should not include options"}
  end

  @spec validate_opening_block_tag(%Tag{}) :: {:error, String.t()}
  defp validate_opening_block_tag(%Tag{name: ""}) do
    {:error, "Opening block tags require a name, e.g. {{#foo}}"}
  end

  @spec validate_opening_block_tag(%Tag{}) :: {:error, String.t()} | :ok
  defp validate_opening_block_tag(_tag), do: :ok

  @spec validate_partial_tag(%Tag{}) :: {:error, String.t()}
  defp validate_partial_tag(%Tag{name: ""}) do
    {:error, "Partial tags require a name, e.g. {{>foo}}"}
  end

  @spec validate_partial_tag(%Tag{}) :: :ok
  defp validate_partial_tag(_tag), do: :ok

  @spec validate_regular_tag(%Tag{}) :: {:error, String.t()}
  defp validate_regular_tag(%Tag{name: ""}) do
    {:error, "Regular tags require a name, e.g. {{foo}}"}
  end

  @spec validate_regular_tag(%Tag{}) :: atom
  defp validate_regular_tag(_tag), do: :ok

  @doc """
  This function exists to make EEx warnings about unused variables go away.
  Shut up 'n play yer guitar!
  """
  @spec shutup(any) :: String.t()
  def shutup(_), do: ""

  def build_helper_parsing_regex(helpers_struct) do
    available_helpers =
      helpers_struct
      |> Map.from_struct()
      |> Enum.map(fn {_, v} -> v end)
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.reject(&(&1 =~ ~r/__.*__/))

    if available_helpers == [] do
      nil
    else
      helper_prefix =
        available_helpers
        # greedy match
        |> Enum.sort_by(&String.length/1, :desc)
        |> Enum.join("|")

      Regex.compile!("^(?<tag_name>#{helper_prefix})(?<tag_options>.*)", "u")
    end
  end
end
