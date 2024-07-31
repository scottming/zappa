defmodule Zappa.Sendgrid.HandlerbarsReferenceTest do
  @moduledoc """
  https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars
  """
  use ExUnit.Case

  # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#substitution
  describe "Substitution" do
    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#basic-replacement
    test "Basic replacement" do
      assert Zappa.Sendgrid.compile(~S|<p>Hello {{ firstName }}</p>|) ==
               {:ok, ~S|<p>Hello <%= @firstName %></p>|}
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#dynamic-link-values
    test "Dynamic link values" do
      assert Zappa.Sendgrid.compile(~S|<p><a href="{{ url }}">Click Me</a></p>|) ==
               {:ok, ~S|<p><a href="<%= @url %>">Click Me</a></p>|}
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#deep-object-replacement
    test "Deep object replacement" do
      assert Zappa.Sendgrid.compile(~S|<p>Hello {{user.profile.firstName}}</p>|) ==
               {:ok, ~S|<p>Hello <%= get_in(@user, [:profile, :firstName]) %></p>|}
    end
  end

  # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#conditional-statements
  describe "Conditional statements" do
    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#basic-if-else-else-if
    test "Basic If, Else, Else If" do
      assert {:ok, tmpl} =
               Zappa.Sendgrid.compile("""
               {{#if user.profile.male}}
               <p>Dear Sir</p>
               {{else if user.profile.female}}
               <p>Dear Madame</p>
               {{else}}
               <p>Dear Customer</p>
               {{/if}}
               """)

      assert tmpl ==
               "<%= cond do %>\n<% get_in(@user, [:profile, :male]) -> %>\n<p>Dear Sir</p>\n<% get_in(@user, [:profile, :female]) -> %>\n\n<p>Dear Madame</p>\n<% true -> %>\n<p>Dear Customer</p>\n<% true -> %><% nil %>\n<% end %>\n\n"
    end

    test "If" do
      assert Zappa.Sendgrid.compile("""
             {{#if user}}
             <p>Dear Sir</p>
             {{else}}
             <p>Dear Customer</p>
             {{/if}}
             """) ==
               {:ok,
                "<%= cond do %>\n<% @user -> %>\n<p>Dear Sir</p>\n<% true -> %>\n<p>Dear Customer</p>\n<% true -> %><% nil %>\n<% end %>\n\n"}
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#equals
    test "Equals" do
      assert Zappa.Sendgrid.compile("""
             <p>
             Hello Ben!
             {{#equals customerCode winningCode}}
             You have a winning code.
             {{/equals}}
             Thanks for playing.
             </p>
             """) ==
               {:ok,
                "<p>\nHello Ben!\n<%= cond do %>\n<% @customerCode == @winningCode -> %>\nYou have a winning code.\n<% true -> %><% nil %>\n<% end %>\n\nThanks for playing.\n</p>\n"}
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#or
    test "Or" do
      assert Zappa.Sendgrid.compile("""
             <p>
             Hello Ben!
             {{#or customerCode winningCode}}
             You have a winning code.
             {{/or}}
             Thanks for playing.
             </p>
             """) ==
               {:ok,
                "<p>\nHello Ben!\n<%= cond do %>\n<% @customerCode || @winningCode -> %>\nYou have a winning code.\n<% true -> %><% nil %>\n<% end %>\n\nThanks for playing.\n</p>\n"}
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#unless
    test "Unless" do
      assert Zappa.Sendgrid.compile(
               "{{#unless user.active}}<p>Warning! Your account is suspended, please call: {{@root.supportPhone}}</p>{{/unless}}"
             ) ==
               {:ok,
                "<%= cond do %>\n<% !get_in(@user, [:active]) -> %><p>Warning! Your account is suspended, please call: <%= @supportPhone %></p><% end %>\n"}
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#and
    test "And" do
      assert Zappa.Sendgrid.compile("{{#and foo bar}} baz {{/and}}") ==
               {:ok,
                "<%= cond do %>\n<% @foo && @bar -> %> baz <% true -> %><% nil %>\n<% end %>\n"}
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#insert
    test "insert" do
      assert Zappa.Sendgrid.compile(~S|<p>Hello {{insert name "Customer"}}!|) ==
               {:ok, ~S(<p>Hello <%= @name || "Customer" %>!)}

      assert Zappa.Sendgrid.compile(
               ~S|<p>Hello {{insert name "default=Customer"}}! Thank you for contacting us about {{insert businessName "your business"}}.</p>|
             ) ==
               {:ok,
                ~S(<p>Hello <%= @name || "Customer" %>! Thank you for contacting us about <%= @businessName || "your business" %>.</p>)}
    end

    test "else with conditon" do
      assert Zappa.Sendgrid.compile("""
             {{#if user.profile.male}}
             <p>Dear Sir</p>
             {{else if user.profile.female}}
             <p>Dear Madame</p>
             {{else and cond1 cond2}}
             <p>Dear Customer</p>
             {{else equals var1 var2}}
             <p>Dear equal</p>
             {{else greaterThan var1 var2}}
             <p>Dear greaterThan</p>
             {{else lessThan var1 var2}}
             <p>Dear lessThan</p>
             {{else notEquals var1 var2}}
             <p>Dear notEquals</p>
             {{else or cond1 cond2}}
             <p>Dear or</p>
             {{else unless cond}}
             <p>Dear unless</p>
             {{else}}
             <p>Dear Fallback</p>
             {{/if}}
             """) ==
               {:ok,
                """
                <%= cond do %>
                <% get_in(@user, [:profile, :male]) -> %>
                <p>Dear Sir</p>
                <% get_in(@user, [:profile, :female]) -> %>

                <p>Dear Madame</p>
                <% @cond1 && @cond2 -> %>

                <p>Dear Customer</p>
                <% @var1 == @var2 -> %>

                <p>Dear equal</p>
                <% @var1 > @var2 -> %>

                <p>Dear greaterThan</p>
                <% @var1 < @var2 -> %>

                <p>Dear lessThan</p>
                <% @var1 != @var2 -> %>

                <p>Dear notEquals</p>
                <% @cond1 || @cond2 -> %>

                <p>Dear or</p>
                <% !@cond -> %>

                <p>Dear unless</p>
                <% true -> %>
                <p>Dear Fallback</p>
                <% true -> %><% nil %>
                <% end %>

                """}
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#basic-iterator-with-each
    test "basic iterator with each" do
      assert {:ok, compiled_string} =
               """
               <ol>
               {{#each user.orderHistory}}
               <li>You ordered: {{this.item}} on: {{this.date}}</li>
               {{/each}}
               </ol>
               """
               |> Zappa.Sendgrid.compile()

      assert EEx.eval_string(
               compiled_string,
               assigns: [
                 user: %{
                   orderHistory: [
                     %{date: "2/1/2018", item: "shoes"},
                     %{date: "1/4/2017", item: "hat"}
                   ]
                 }
               ]
             ) ==
               "<ol>\n\n  \n<li>You ordered: shoes on: 2/1/2018</li>\n\n\n  \n<li>You ordered: hat on: 1/4/2017</li>\n\n\n\n</ol>\n"
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#combined-examples
    test "combined examples" do
      assert {:ok, compiled_string} =
               """
               {{#each user.story}}
               {{#if this.male}}
               <p>{{this.date}}</p>
               {{else if this.female}}
               <p>{{this.item}}</p>
               {{/if}}
               {{/each}}
               """
               |> Zappa.Sendgrid.compile()

      assert EEx.eval_string(
               compiled_string,
               assigns: [
                 user: %{
                   story: [
                     %{male: true, date: "2/1/2018", item: "shoes"},
                     %{male: true, date: "1/4/2017", item: "hat"},
                     %{female: true, date: "1/1/2016", item: "shirt"}
                   ]
                 }
               ]
             ) ==
               "\n  \n\n<p>2/1/2018</p>\n\n\n\n\n  \n\n<p>1/4/2017</p>\n\n\n\n\n  \n\n\n<p>shirt</p>\n\n\n\n\n\n"
    end
  end
end
