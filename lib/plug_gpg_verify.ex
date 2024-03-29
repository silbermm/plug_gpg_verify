defmodule PlugGPGVerify do
  @moduledoc """
  plug_gpg_verify does the work of verifing a public key by generating a random 
  challenge, sending that challenge to the user and expecting the response, having
  the client sign the challenge and send it back, then verifying the signature.

  This makes a couple of assumptions:
  1. GPG is setup and working correctly on your system.
      -  this uses [gpgmex](https://hexdocs.pm/gpgmex/GPG.html) which requires the rust toolchain installed and working
  2. The public key we are validating has already been imported

  What this is **NOT**
  1. This is **NOT** a way to authenticate. Authentication is left as an excersise to the user of the library
  2. This does **NOT** in any way import PGP keys, or verify that the email associated with the public_key
  is valid.

  ## Example Usage
  Put this plug somewhere in your router
  ```elixir
  scope "/verify" do
    pipe_through(:api)
    forward "/", PlugGPGVerify, adapter: MyProject.GPGVerificationPlug
  end
  ```

  Create a module that implements the PlugGPGVerify behaviour
  ```elixir
  defmodule MyProject.GPGVerificationPlug do
    use PlugGPGVerify

    @impl true
    def find_user_by_email(email) do
      case Repo.get_by(User, :email, email) do
        nil -> {:error, :not_found}
        user -> {:ok, %{id: user.id, email: user.email}}
      end
    end

    @impl true
    def challenge_created(user, challenge) do
      changeset = User.changeset(
        %User{id: user.id, email: user.email}, 
        %{
          challenge: plain_text_challenge,
          challenge_expiration: DateTime.add(DateTime.utc_now(), 1, :hour)
        }
      )
      Repo.update(changeset)
    end

    @impl true
    def find_user_by_id(id) do
      case Repo.get(User, id) do
        nil -> {:error, :not_found}
        user ->
          # verify expiration
          {:ok, %{id: user.id, email: user.email, challenge: challenge}}
      end
    end

    @impl true
    def gpg_verified(conn, user) do 
      # do whatever you want with the connection
      token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user auth", user.id)
      conn
      |> put_status(200)
      |> Controller.json(%{token: token})
    end
  end
  ```

  Your application accepts two new requests at `/verify` (or whatever route you defined): 
  * GET /verify?email="user@email.com"
  * POST /verify

  ### GET /verify
  If a user is found (via the `c:find_user_by_email/1` callback),
  AND they have a public_key configured on the system, a new challenge is generated and encrypted.

  A 201 is sent back with a JSON response of:
  ```json
  {
    challenge: string,
    user_id: string
  }
  ```

  ### POST /verify
  This accepts a json body of:
  ```json
  {
    challenge_response: string,
    user_id: string
  }
  ```
  where challenge_response is the signed challenge

  ## Flow Diagram

  ```mermaid
  sequenceDiagram
    Client->>Server: GET /verify?email=example@email.com
    Server->>Client: {user_id: 1234, challenge: "challenge string"}
    Client->>Server: POST /verify {user_id: 1234, challenge_response: "-----BEGIN PGP MESSAGE----- ..."}
    Server->>Client: 200
  ```
  """

  @behaviour Plug
  alias Plug.Conn
  alias PlugGPGVerify.Verification

  @impl Plug
  def init(adapter: adapter), do: adapter
  def init(_), do: raise("adapter is a required option for PlugGPGVerify")

  @impl Plug
  def call(%{method: method} = conn, module) do
    case validate_method(method) do
      :invalid -> Verification.invalid_method(conn)
      :get -> Verification.generate_challenge(conn, module)
      :post -> Verification.validate_challenge(conn, module)
    end
  end

  @spec validate_method(String.t()) :: :get | :post | :invalid
  defp validate_method(method) do
    case String.downcase(method) do
      "get" -> :get
      "post" -> :post
      _other -> :invalid
    end
  end

  @typep email :: binary()
  @typep id :: any()
  @type challenge() :: binary()

  @typedoc """
  The entity passed between the plug and the callbacks
  """
  @type user :: %{id: id(), email: email(), challenge: challenge()}

  @doc """
  Find a user based on the email sent in the GET request

  Typically this is would call into the database to find a user and that user should have a public_key.
  Then it is mapped to a `t:PlugGPGVerify.user/0` and returned in an `:ok` tuple.

  If this returns an error, a 406 is sent back to the client.
  """
  @callback find_user_by_email(email()) :: {:ok, user()} | {:error, any()}

  @doc """
  Find a user based on the id sent back via the POST request.

  When the client sends the POST request, the are required to send the id of the user back
  instead of relying on the email. This callback is called to get the `t:PlugGPGVerify.user/0`
  including the orginial `t:PlugGPGVerify.challenge/0` created.

  Most implementations will also verify that the challenge hasn't expired based on their own
  rules.

  If an `{:ok, user}` is returned, verification continues

  If an `{:error, reason}` is returned, a 401 is sent back to the client
  """
  @callback find_user_by_id(id()) :: {:ok, user()} | {:error, any()}

  @doc """
  Called when the challenge is successfully created.

  It is expected that the implementation stores the challenge somewhere to be recalled when
  `c:find_user_by_id/1` is called during the POST request. 

  It is also recommended to store an expiration date with the challenge.
  """
  @callback challenge_created(user(), challenge()) :: :ok | {:error, binary()}

  @doc """
  Called when the GPG public key has been verified because the challenge matches.

  This is the final step in the happy path of verification.

  This will return the `Plug.Conn` and it's up to the implementation to handle next steps.

  Most implementations will likely generate a token, return it to the user and store it in the session/db.
  """
  @callback gpg_verified(Conn.t(), user()) :: Conn.t()

  defmacro __using__(_) do
    quote location: :keep do
      require unquote(__MODULE__)
      @behaviour PlugGPGVerify
    end
  end
end
