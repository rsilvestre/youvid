# Youvid Development Guidelines

## Common Commands
- Run all tests: `mix test`
- Run a specific test: `mix test test/youvid_test.exs:LINE_NUMBER`
- Format code: `mix format`
- Lint with Credo: `mix credo`
- Type checking with Dialyzer: `mix dialyzer`
- Generate docs: `mix docs`

## Code Style and Conventions
- Use `typed_struct` for defining structs with typespecs
- Return values follow `{:ok, result}` or `{:error, reason}` pattern
- Functions with `!` suffix raise exceptions instead of returning error tuples
- Module aliases should be grouped and alphabetized
- Use `with` statements for multi-step operations with error handling
- Types are defined in the central `Youvid.Types` module
- Keep modules focused on a single responsibility
- Format according to Elixir standards (`mix format` handles this)
- Prefer explicit typing with `@spec` for public functions
- Use pattern matching in function definitions when appropriate