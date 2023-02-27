defmodule PlugGPGVerifyTest do
  use ExUnit.Case, async: true
  use Plug.Test

  doctest PlugGPGVerify

  import Mox

  setup :verify_on_exit!

  test "GET happy path" do
    conn = conn(:get, "/validate", %{"email" => "test@test.com"})

    expect(PlugGPGVerify.TestAdapter, :find_user_by_email, fn email ->
      assert email == "test@test.com"
      {:ok, %{id: 1234, email: email}}
    end)

    expect(PlugGPGVerify.TestAdapter, :challenge_created, fn _user, _challenge, _plain_text ->
      :ok
    end)

    opts = PlugGPGVerify.init(adapter: PlugGPGVerify.TestAdapter)
    conn = PlugGPGVerify.call(conn, opts)

    assert conn.state == :sent
    assert conn.status == 200
  end

  test "GET without proper parameters" do
    conn = conn(:get, "/validate", %{})
    opts = PlugGPGVerify.init(adapter: PlugGPGVerify.TestAdapter)
    conn = PlugGPGVerify.call(conn, opts)

    assert conn.state == :sent
    assert conn.status == 406
  end

  test "GET email not found" do
    expect(PlugGPGVerify.TestAdapter, :find_user_by_email, fn _email ->
      {:error, :not_found}
    end)

    conn = conn(:get, "/validate", %{"email" => "noexist@test.com"})
    opts = PlugGPGVerify.init(adapter: PlugGPGVerify.TestAdapter)
    conn = PlugGPGVerify.call(conn, opts)

    assert conn.state == :sent
    assert conn.status == 406
  end
end
