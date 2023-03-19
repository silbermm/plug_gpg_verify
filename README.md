# plug_gpg_verify

A plug that can be used to verify the ownership of public gpg keys.

## TLDR;

It simply generates a random phrase and sends that to the user.
The user then is required to sign the phrase and send it back which can then be verified.


## Installation

Add `plug_gpg_verify` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:plug_gpg_verify, "~> 0.1.0"}
  ]
end
```

This plug makes use of a gpg library that requires:
* the `rust` toolchain to be installed
* gpg to be installed and configured properly

## Usage


Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/plug_gpg_verify>.
