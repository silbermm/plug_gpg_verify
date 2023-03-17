defmodule PlugGPGVerify.Verification do
  @moduledoc false

  import Plug.Conn
  alias Plug.Conn

  @doc "Send 406 Invalid Request"
  @spec invalid_method(Conn.t()) :: Conn.t()
  def invalid_method(conn), do: send_resp(conn, 405, "Invalid Method")

  @doc "Generates a challenge and sends the JSON response"
  @spec generate_challenge(Conn.t(), module()) :: Conn.t()
  def generate_challenge(%{params: %{"email" => ""}} = conn, _adapter),
    do: send_resp(conn, 406, "Invalid Request")

  def generate_challenge(%{params: %{"email" => email}} = conn, adapter) do
    user = apply(adapter, :find_user_by_email, [email])

    case user do
      {:ok, user} ->
        create_and_save_challenge(conn, user, adapter)

      {:error, _reason} ->
        send_resp(conn, 406, "Invalid Request")
    end
  end

  def generate_challenge(conn, _adapter), do: send_resp(conn, 406, "Invalid Request")

  defp create_and_save_challenge(conn, user, adapter) do
    dice = Diceware.generate()

    apply(adapter, :challenge_created, [user, dice.phrase])
    json = Jason.encode!(%{challenge: dice.phrase, user_id: user.id})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  def validate_challenge(
        %{params: %{"user_id" => id, "challenge_response" => challenge_resp}} = conn,
        adapter
      ) do
    case apply(adapter, :find_user_by_id, [id]) do
      {:ok, user} ->
        if is_valid_challenge_response?(user, challenge_resp) do
          apply(adapter, :gpg_verified, [conn, user])
        else
          send_resp(conn, 401, "")
        end

      {:error, _reason} ->
        send_resp(conn, 401, "Unauthorized")
    end
  end

  def validate_challenge(%{params: _params} = conn, _module) do
    send_resp(conn, 406, "Invalid Body")
  end

  defp is_valid_challenge_response?(user, challenge_resp) do
    case GPG.verify_clear(challenge_resp) do
      {:ok, data} ->
        user.challenge == String.replace(data, "\n", "")

      {:error, _err} ->
        false
    end
  end
end
