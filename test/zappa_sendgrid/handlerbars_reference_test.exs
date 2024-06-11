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
               {:ok, ~S|<p>Hello <%= @user.profile.firstName %></p>|}
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
               "<%= cond do %>\n<% @user.profile.male -> %>\n<p>Dear Sir</p>\n<% @user.profile.female -> %>\n\n<p>Dear Madame</p>\n<% true -> %>\n<p>Dear Customer</p>\n<% true -> %><% nil %>\n<% end %>\n\n"
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
                "<p>\nHello Ben!\n<%= if (@customerCode == @winningCode) %>\nYou have a winning code.\n<% end %>\nThanks for playing.\n</p>\n"}
    end

    # https://www.twilio.com/docs/sendgrid/for-developers/sending-email/using-handlebars#unless
    test "Unless" do
      assert Zappa.Sendgrid.compile(
               "{{#unless user.active}}<p>Warning! Your account is suspended, please call: {{@root.supportPhone}}</p>{{/unless}}"
             ) ==
               {:ok,
                "<%= cond do %>\n<% not @user.active -> %><p>Warning! Your account is suspended, please call: <%= @supportPhone %></p><% end %>\n"}
    end
  end
end
