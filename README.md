# test-tube

![test](https://github.com/merlins-labs/test-tube/actions/workflows/test.yml/badge.svg)

`test-tube` is a generic library for building testing environments for [CosmWasm](https://cosmwasm.com/) smart contracts. It allows you to test your smart contract logic against the actual Cosmos SDK chain's logic, which is written in Go, using Rust. This eliminates the need to write Go code or learn Go in order to test your smart contracts against the Cosmos SDK.

`test-tube` is currently used to build [`merlin-test-tube`](https://github.com/merlins-labs/test-tube/tree/main/packages/merlin-test-tube), but it can be used to build testing environments for any Cosmos SDK-based chain. To do this, you will need to build a shared library that exports the functions described [here](https://github.com/merlins-labs/test-tube/blob/ddae11d003b5d900bdee2026034b9b1d4c33bdb3/packages/test-tube/src/bindings.rs#L211-L241). You can use the [Go code](https://github.com/merlins-labs/test-tube/tree/main/packages/merlin-test-tube/libmerlintesttube) and [build script](https://github.com/merlins-labs/test-tube/blob/main/packages/merlin-test-tube/build.rs) from `merlin-test-tube` as a reference.

## Features

- Test your CosmWasm smart contracts using Rust without the need to write Go code or learn Go
- Test against the actual Cosmos SDK chain's logic
- Build testing environments for any Cosmos SDK-based chain

## Why don't just use `cw-multi-test`?

You might want to just use `cw-multi-test` if your contract does not interact with chain's custom module.
`cw-multi-test` is faster since it does not need to run the chain code or build and upload `.wasm` file, but it does not test your contract against the actual chain's logic and rely on simulation which only some basic modules are implemented.

So if your contract just interact with common modules like Bank, Staking, and Distribution, `cw-multi-test` is enough. But if it's interacting with custom modules, you should use `test-tube`.

## Contributing

We welcome contributions to `test-tube`! If you find a bug or have an idea for a new feature, please open an issue or submit a pull request.

## License

The crates in this repository are licensed under either of the following licenses, at your discretion.

    Apache License Version 2.0 (LICENSE-APACHE or apache.org license link)
    MIT license (LICENSE-MIT or opensource.org license link)

Unless you explicitly state otherwise, any contribution submitted for inclusion in this library by you shall be dual licensed as above (as defined in the Apache v2 License), without any additional terms or conditions.
