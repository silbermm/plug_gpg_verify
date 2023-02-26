defmodule Mix.Tasks.GpgVerify do
  @moduledoc """
  The GPGVerify mix task: `mix help gpg_verify`


  """

  def run(_argv) do
    {:ok, _started} = Application.ensure_all_started(:req)
    url = "http://localhost:4000/login"
    email = "matt@silbernagel.dev"

    case Req.get!("#{url}?email=#{email}") do
      %Req.Response{status: 200, body: body} ->
        challenge = Map.get(body, "challenge")
        user_id = Map.get(body, "user_id")
        response = decrypt_and_send(user_id, challenge, url)
        IO.puts(inspect(response.body))

      _ ->
        IO.puts("Invalid Request")
    end
  end

  defp decrypt_and_send(user_id, challenge, url) do
    case GPG.decrypt(challenge) do
      {:ok, data} ->
        Req.post!("#{url}", json: %{challenge_response: data, user_id: user_id})

      {:error, _reason} ->
        :error
    end
  end
end
