# Strict Lua JSON decoder

Bundled modbus.json_strict ships in the core IPK, runs on Lua 5.1 without LuCI.
Core requirement 6.9.8, TC-128.

json.decode(text, limits) returns value, nil, root_number_form on success;
nil and {code=..., offset=...} on failure. Offset is a one-based byte position,
possibly immediately after input. No partial result. Check the error, not value
truthiness: false is valid JSON.

json.null preserves null and dense arrays. json.kind(value) distinguishes object,
array, null and ordinary Lua types, including empty containers.
json.number_kind(container, key) reports integer for numeric tokens without a
decimal point/exponent, number otherwise. Root form is the third decode result.
Metadata describes the original parse, not subsequent mutations. Validate before
mutation. The legacy encoder does not preserve these types/null.

Rejects duplicate decoded keys, malformed UTF-8, unpaired surrogates, controls,
comments, BOM, trailing commas, invalid number grammar and trailing data.
Numbers must be finite with magnitude at most 9007199254740991.
Fractions retain ordinary Lua number rounding/underflow behavior. Field schema
validation must enforce numeric ranges and integer syntax separately.

| Limit | Default maximum |
| :--- | ---: |
| bytes | 16384 input bytes |
| depth | 8 container levels; root = 1 |
| nodes | 4096 values plus object keys |
| string_bytes | 16384 decoded bytes per string/key |

Overrides may only lower limits using positive integers. Unknown options, invalid
types and option metatables are rejected. Size is checked before parsing.
These limits are not a total RAM budget.

modbus.json.decode_strict(text, limits) exposes the explicit strict path.
Legacy decode retains optional luci.jsonc; cache, topics and CLI are not migrated.
The future Lua profile loader must use depth=3 and separately validate schema,
IDs and the trusted catalogue. Loader implementation and hardware RAM measurements
remain. Tests: lua5.1 scripts/test_json_strict.lua (20 groups), make all.
