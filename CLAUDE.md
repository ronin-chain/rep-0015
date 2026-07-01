CLAUDE.md

Guidance for AI agents working in this repository.

## Build & test — ALWAYS use the local cache

- **Always build incrementally using the local cache. Never force-rebuild.**
  - ✅ `forge build`
  - ❌ `forge build --force` / `forge build -f`
  - ❌ `forge clean` (wipes `out/` and the compile cache, forcing a full slow recompile)
- Foundry's compile cache lives in `cache_foundry/` (see `cache_path` in `foundry.toml`); artifacts live in `out/`. Leave both in place so only changed files recompile.
- If a build looks stale, prefer re-running `forge build` (incremental) over clearing caches. Only clear caches as a deliberate last resort, and say so explicitly.
- Run tests the same way — `forge test` reuses the cache; do not pair it with `--force` or a preceding `forge clean`.

## Useful commands

- Build: `forge build`
- Run all tests: `forge test`
- Run a single test file: `forge test --match-path <testFiles>.t.sol`
- Run a single test: `forge test --match-test <testName> -vvv`

## Project layout

- Contracts: `contracts/`
- Foundry tests: `test/`
- Dependencies are managed with **soldeer** (`[dependencies]` in `foundry.toml`, locked in `soldeer.lock`).

## Testing

Tests are written not only to verify correctness but to be **reviewed** by other programmers — their clarity and elegance matter as much as the code. We defer to the [Moloch Testing Guide](https://github.com/MolochVentures/moloch/tree/master/test#readme) and the [Foundry test naming conventions](https://book.getfoundry.sh/tutorials/best-practices#tests).

### What the suite MUST contain

- **At least one concrete test per external method**: static input → static output. Deriving the expected output by calculation, inference, or fuzzing is NOT allowed in that concrete test.
- Handle **all possible cases** with concrete tests. Fuzzing is good but not a silver bullet — never rely on fuzz alone.
- Every addition or change to the code ships with relevant, comprehensive tests.
- Keep coverage as close to **100%** as possible (enforced in PRs) — but optimize for well-thought-out tests, not the coverage number.
- **Refactors must not change code and tests simultaneously.**
- **No flaky tests.** The suite runs in CI on every change and must pass before merging.

### Positive & negative tests (samczsun)

- **Positive** tests for what the code SHOULD handle — validate *every* piece of state that changes.
- **Negative** tests for what it should NOT handle; it helps to follow each with an adjacent positive test that makes the change needed to pass.
- Each code path gets its own unit test.
- Add **integration** tests for whole features and **fork** tests to verify behavior against already-deployed contracts.
- When unit tests are insufficient, complement with property-based tests (fuzzing) for math-heavy code and formal verification for state machines.

### Never use `testFail_*`

- `testFail_*` passes on ANY revert and disregards `vm.expectRevert()` — a false-positive, flaky trap that breaks the atomic "one test passes only under one condition" property. Always assert the specific revert with `vm.expectRevert(<selector>)`.

### Naming

- Each test runs a fresh `setUp()`, so contract state is isolated per test.
- Conforms to the regex `^test(Fork)?(Fuzz)?(_Revert(If|When|On))?_(\w+)*$`. In this repo the target function comes first, then the outcome modifier, then the condition, `_`-separated:

  `test[Fork][Fuzz]_<function>[_<Outcome>]_<condition>[_<moreInfo>]`

  where `<Outcome>` is `RevertIf` / `RevertWhen` / `RevertOn` for negatives, or `SuccessWhen` / `Return<X>When` for positives.
  - `test_setContextLock_RevertWhen_CallerIsNotController`
  - `testFuzz_startDelegateOwnership_SuccessWhen_PreviousOwnershipDelegationExpired`
  - `test_isTokenContextLocked_ReturnFalseWhen_NotAttachedContext`
- **Group** tests for the same function/condition next to each other for easier review.
- Test methods are `external` by default, unless recycled by other tests.

## Coding conventions

_Adapted from the OpenZeppelin Solidity Style Guide (with repo-specific modifications). Also follow the official Solidity Style Guide. Prioritize readability, consistency, and predictability; break a rule only for significant efficiency gains, and add an explanatory comment when you do._

### Interfaces & overrides (repo-specific)

- **Interfaces carry the API surface.** For a contract `Foo`, define an `IFoo` interface (under `contracts/interfaces/…`, mirroring the contract's path — e.g. `contracts/land/LandItem.sol` → `contracts/interfaces/land/ILandItem.sol`) that holds **all** `struct`s, custom `error`s, `event`s, and external/public function signatures, each with its NatSpec (`@notice` / `@dev`). The implementing contract `is IFoo` and annotates each implementation with `/// @inheritdoc IFoo` instead of repeating the docs. Keep the contract body free of struct/error/event definitions and behavioral doc comments (short `@dev` notes on implementation-only details like proxy/immutable behavior are fine).
- Public state variables (including `constant`s) may implement interface getters directly — annotate them with `/// @inheritdoc IFoo`.
- This repo compiles with Solidity ≥0.8.8, so implementing a function that comes from a **single** interface does **not** need the `override` keyword. Only reserve `override(...)` for genuine multi-base overrides (e.g. `supportsInterface`, ERC721's `_update`).

### General

- **All state variables MUST be private/internal**; mutate them only through setters that emit events (encapsulation guarantees events/rules are honored). Prefer `internal` over `private` for flexibility during development; declaring state `public` is discouraged.
- **Always wrap `if`/`else` bodies in curly braces**, even single-line ones. Exception: an `if`-body that contains only a `revert`.

### Naming — underscore denotes state, not visibility

- `_` prefix is reserved for **state** variables/functions. Internal/private state variables **and** functions MUST be `_`-prefixed. Exception: **library functions MUST NOT** have a `_` prefix.
- **Local storage pointers** MUST be `_`-prefixed (`$` allowed but discouraged unless it points to a custom slot).
- **Local memory variables** SHOULD be `m`-prefixed (e.g. `mBalance`).
- **Non-storage locals** — in-method vars, params, and returns — MUST NOT have a `_` prefix.
- On a **naming collision**, add a trailing `_` suffix (e.g. `secretKey_`).

### Name casing

- `constant` → `ALL_CAPS_WITH_UNDERSCORES` (exception: a constant holding a custom storage-slot value).
- `immutable` → `i_camelCase` (assigned only in the constructor).
- Enum name and members → `PascalCase`; index-0 member SHOULD be `Unknown` (avoids using an uninitialized value); comment each member with its index.

### Prefixes

- Interface → `I` prefix. Custom error → ERC-6093 grammar (`<Domain><ErrorPrefix><Subject>`) or an `Err` prefix. Custom type → `T` prefix.

### Custom storage slots (`$`)

- `$` is reserved for storage-related variables in custom-slot contracts. The struct representing storage MUST be suffixed `Storage`, with all members `_`-prefixed. Pointers to the slot MUST be named `$` or `$_<name>`. The slot constant MUST be `constant`, named `$$_<something>StorageLocation`, keccak-derived and masked in the last byte.

### Values, arrays, singular vs plural

- Primitive-value variables → singular noun (`totalCount`, `id`). Arrays/lists → plural (`ids`), or use an `Arr`/`Lst`/`List` suffix or a group name (`schoolOfFish`).

### Ordering

- Contract-level declarations MUST be ordered: `constant` → `immutable` → variables.

### Events & comments

- Emit events **immediately after** the state change they represent, named in the **past tense** (unless a standard like ERC20 mandates present tense).
- Comment every `unchecked` block (why overflow can't happen — omit only if obvious from the line above), every assembly block (the *what*), and any obscure/gas-hack/unconventional syntax.
- `using Lib for <Type>` — always name the explicit type; never `using Lib for *`. Call unrelated library methods via the library name.

### Custom errors

- Declare **all** errors in a single shared file; contract-level error declarations are discouraged.
- Keep reverts on one line — `if (cond) revert ErrX();` — with **no** braces and **no** line break between `if` and `revert`. Use braces only when the line is too long to fit.

### Batch getters

- Discouraged (they cost significant code size; DApps can batch via Multicall). When a batch getter is genuinely needed internally/cross-contract, name it with the `Many` keyword plus an `-s` suffix, consistent with the singular getter (e.g. `getOperator` → `getManyOperators`).

## Common Development Checklist

### Upgradeable

- **Reserve storage gaps** (when NOT using custom slots): add a **top-gap** in the innermost contract (room for future inherited contracts) and a **below-gap** in every inner contract and every struct.
- **Custom slots**: use OpenZeppelin's custom-slot standard (it ignores the last byte of the slot). Declare the variables in one `Storage` struct pinned to a single slot location; consider grouping variables by usage. See _Custom storage slots (`$`)_ under Coding conventions.
- **Storage slots MUST NOT shift before an upgrade** — verify both by (1) reading the code and (2) checking the storage-layout log.
- Remember the layout can shift from **either** a change in declaration order **or** a change in the C3-linearization result (inheritance order).
- SHOULD spot-check values in storage slots in simulation to confirm no slot shifted.

### Pausable

- SHOULD apply the Pausable pattern to **all** contracts by default. Remove only if a C-level requests it — proactively suggest/remind the Product Owner about this feature.
- MUST add `whenNotPaused` to all crucial methods.
- MUST expose `pause() onlyRole(x)` and `unpause() onlyRole(x)` (commonly forgotten).

### Initializable

- Prefer `TransparentUpgradeableProxy` (TransparentProxyV2) in most cases; **UUPS is extremely discouraged**.
- MUST call `_disableInitializers()` in the constructor — verify repeatedly if the proxy is UUPS.
- All crucial state variables MUST be set in the `initializer` / `reinitializer(x)`.
- MUST check the contract version **before AND after** an upgrade (via Skynet call or simulation).
- MUST NOT change the logic of any previous `initialize` method under any circumstance — only variable renames (usually deprecating) are acceptable. Otherwise deploying a fresh contract that must run through many initializers breaks.
- If OpenZeppelin's `_version` variable is `internal`, expose a `version()` external getter (easier than a Skynet call or `getStorageAt`).

### External calls with success handling

- **Production**: prefer `abi.encodeCall` over `abi.encodeWithSelector` for type checking.
- **Simulation / post-checks**: prefer `.call` and check the returned `success` flag over the direct `.<function>()` call, to catch ABI changes.

### Using assembly

- DO NOT use `mstore` to **extend** the size of a memory array (it breaks memory allocation). You CAN use `mstore` to **shrink** one.
- SHOULD confirm memory safety and mark such blocks `assembly ("memory-safe")` so the compiler knows the block is safe for certain optimizations.
