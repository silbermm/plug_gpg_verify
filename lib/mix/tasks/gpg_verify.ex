defmodule Mix.Tasks.GpgVerify do
  @moduledoc """
  A task to help check if plug_gpg_verify is setup correctly.

  ## Usage
  `mix gpg_verify <email>`

  ### Options
    * --url <url> defaults to http://localhost:4000/verify
  """

  def run(argv) do
    {:ok, _started} = Application.ensure_all_started(:req)

    case OptionParser.parse(argv, strict: [url: :string]) do
      {opts, [email], _} ->
        url = Keyword.get(opts, :url, "http://localhost:4000/verify")
        do_send(url, email)

      {_opts, [], _} ->
        IO.puts("Email is required")
    end
  end

  defp do_send(url, email) do
    IO.puts("Checking #{url} and #{email} for validity")

    case Req.get!("#{url}?email=#{email}") do
      %Req.Response{status: 200, body: body} ->
        challenge = Map.get(body, "challenge")
        user_id = Map.get(body, "user_id")
        response = sign_and_send(user_id, challenge, url)
        IO.puts(inspect(response.body))
        response.body

      _ ->
        IO.puts("Invalid Request")
        %{}
    end
  end

  defp sign_and_send(user_id, challenge, url) do
    case GPG.clear_sign(challenge) do
      {:ok, data} ->
        Req.post!("#{url}", json: %{challenge_response: data, user_id: user_id})

      {:error, _reason} ->
        :error
    end
  end
end
