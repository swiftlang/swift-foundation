# Parse Test Cases for JSON5

The test cases' file extension signals the expected behavior:

- Valid JSON should remain valid JSON5. These cases have a `.json` extension
  and are tested via `JSON.parse()`.

- JSON5's new features should remain valid ES5. These cases have a `.json5`
  extension are tested via `eval()`.

- Valid ES5 that's explicitly disallowed by JSON5 is also invalid JSON. These
  cases have a `.js` extension and are expected to fail.

- Invalid ES5 should remain invalid JSON5. These cases have a `.txt` extension
  and are expected to fail.

This should cover all our bases. Most of the cases are unit tests for each
supported data type, but aggregate test cases are welcome, too.

## License

MIT. See [LICENSE.md](./LICENSE.md) for details.
