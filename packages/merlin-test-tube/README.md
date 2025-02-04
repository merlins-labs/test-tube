# merlin-test-tube

[![merlin-test-tube on crates.io](https://img.shields.io/crates/v/merlin-test-tube.svg)](https://crates.io/crates/merlin-test-tube) [![Docs](https://docs.rs/merlin-test-tube/badge.svg)](https://docs.rs/merlin-test-tube)

CosmWasm x Merlin integration testing library that, unlike `cw-multi-test`, it allows you to test your cosmwasm contract against real chain's logic instead of mocks.

## Table of Contents

- [Getting Started](#getting-started)
- [Debugging](#debugging)
- [Using Module Wrapper](#using-module-wrapper)
- [Custom Module Wrapper](#custom-module-wrapper)
- [Versioning](#versioning)

## Getting Started

To demonstrate how `merlin-test-tube` works, let use simple example contract: [cw-whitelist](https://github.com/CosmWasm/cw-plus/tree/main/contracts/cw1-whitelist) from `cw-plus`.

Here is how to setup the test:

```rust
use cosmwasm_std::Coin;
use merlin_test_tube::MerlinTestApp;

// create new merlin appchain instance.
let app = MerlinTestApp::new();

// create new account with initial funds
let accs = app
    .init_accounts(
        &[
            Coin::new(1_000_000_000_000, "uatom"),
            Coin::new(1_000_000_000_000, "ufury"),
        ],
        2,
    )
    .unwrap();

let admin = &accs[0];
let new_admin = &accs[1];
```

Now we have the appchain instance and accounts that have some initial balances and can interact with the appchain.
This does not run Docker instance or spawning external process, it just load the appchain's code as a library create an in memory instance.

Note that `init_accounts` is a convenience function that creates multiple accounts with the same initial balance.
If you want to create just one account, you can use `init_account` instead.

```rust
use cosmwasm_std::Coin;
use merlin_test_tube::MerlinTestApp;

let app = MerlinTestApp::new();

let account = app.init_account(&[
    Coin::new(1_000_000_000_000, "uatom"),
    Coin::new(1_000_000_000_000, "ufury"),
]);
```

Now if we want to test a cosmwasm contract, we need to

- build the wasm file
- store code
- instantiate

Then we can start interacting with our contract. Let's do just that.

```rust
use cosmwasm_std::Coin;
use cw1_whitelist::msg::{InstantiateMsg}; // for instantiating cw1_whitelist contract
use merlin_test_tube::{Account, Module, MerlinTestApp, Wasm};

let app = MerlinTestApp::new();
let accs = app
    .init_accounts(
        &[
            Coin::new(1_000_000_000_000, "uatom"),
            Coin::new(1_000_000_000_000, "ufury"),
        ],
        2,
    )
    .unwrap();
let admin = &accs[0];
let new_admin = &accs[1];

// ============= NEW CODE ================

// `Wasm` is the module we use to interact with cosmwasm releated logic on the appchain
// it implements `Module` trait which you will see more later.
let wasm = Wasm::new(&app);

// Load compiled wasm bytecode
let wasm_byte_code = std::fs::read("./test_artifacts/cw1_whitelist.wasm").unwrap();
let code_id = wasm
    .store_code(&wasm_byte_code, None, admin)
    .unwrap()
    .data
    .code_id;
```

Not that in this example, it loads wasm bytecode from [cw-plus release](https://github.com/CosmWasm/cw-plus/releases) for simple demonstration purposes.
You might want to run `cargo wasm` and find your wasm file in `target/wasm32-unknown-unknown/release/<contract_name>.wasm`.

```rust
use cosmwasm_std::Coin;
use cw1_whitelist::msg::{InstantiateMsg, QueryMsg, AdminListResponse};
use merlin_test_tube::{Account, Module, MerlinTestApp, Wasm};

let app = MerlinTestApp::new();
let accs = app
    .init_accounts(
        &[
            Coin::new(1_000_000_000_000, "uatom"),
            Coin::new(1_000_000_000_000, "ufury"),
        ],
        2,
    )
    .unwrap();
let admin = &accs[0];
let new_admin = &accs[1];

let wasm = Wasm::new(&app);


let wasm_byte_code = std::fs::read("./test_artifacts/cw1_whitelist.wasm").unwrap();
let code_id = wasm
    .store_code(&wasm_byte_code, None, admin)
    .unwrap()
    .data
    .code_id;

// ============= NEW CODE ================

// instantiate contract with initial admin and make admin list mutable
let init_admins = vec![admin.address()];
let contract_addr = wasm
    .instantiate(
        code_id,
        &InstantiateMsg {
            admins: init_admins.clone(),
            mutable: true,
        },
        None, // contract admin used for migration, not the same as cw1_whitelist admin
        None, // contract label
        &[], // funds
        admin, // signer
    )
    .unwrap()
    .data
    .address;

// query contract state to check if contract instantiation works properly
let admin_list = wasm
    .query::<QueryMsg, AdminListResponse>(&contract_addr, &QueryMsg::AdminList {})
    .unwrap();

assert_eq!(admin_list.admins, init_admins);
assert!(admin_list.mutable);
```

Now let's execute the contract and verify that the contract's state is updated properly.

```rust
use cosmwasm_std::Coin;
use cw1_whitelist::msg::{InstantiateMsg, QueryMsg, ExecuteMsg, AdminListResponse};
use merlin_test_tube::{Account, Module, MerlinTestApp, Wasm};

let app = MerlinTestApp::new();
let accs = app
    .init_accounts(
        &[
            Coin::new(1_000_000_000_000, "uatom"),
            Coin::new(1_000_000_000_000, "ufury"),
        ],
        2,
    )
    .unwrap();
let admin = &accs[0];
let new_admin = &accs[1];

let wasm = Wasm::new(&app);


let wasm_byte_code = std::fs::read("./test_artifacts/cw1_whitelist.wasm").unwrap();
let code_id = wasm
    .store_code(&wasm_byte_code, None, admin)
    .unwrap()
    .data
    .code_id;

// instantiate contract with initial admin and make admin list mutable
let init_admins = vec![admin.address()];
let contract_addr = wasm
    .instantiate(
        code_id,
        &InstantiateMsg {
            admins: init_admins.clone(),
            mutable: true,
        },
        None, // contract admin used for migration, not the same as cw1_whitelist admin
        None, // contract label
        &[], // funds
        admin, // signer
    )
    .unwrap()
    .data
    .address;

let admin_list = wasm
    .query::<QueryMsg, AdminListResponse>(&contract_addr, &QueryMsg::AdminList {})
    .unwrap();

assert_eq!(admin_list.admins, init_admins);
assert!(admin_list.mutable);

// ============= NEW CODE ================

// update admin list and rechec the state
let new_admins = vec![new_admin.address()];
wasm.execute::<ExecuteMsg>(
    &contract_addr,
    &ExecuteMsg::UpdateAdmins {
        admins: new_admins.clone(),
    },
    &[],
    admin,
)
.unwrap();

let admin_list = wasm
    .query::<QueryMsg, AdminListResponse>(&contract_addr, &QueryMsg::AdminList {})
    .unwrap();

assert_eq!(admin_list.admins, new_admins);
assert!(admin_list.mutable);
```

## Debugging

In your contract code, if you want to debug, you can use [`deps.api.debug(..)`](https://docs.rs/cosmwasm-std/latest/cosmwasm_std/trait.Api.html#tymethod.debug) which will prints the debug message to stdout. `wasmd` disabled this by default but `MerlinTestApp` allows stdout emission so that you can debug your smart contract while running tests.

## Using Module Wrapper

In some cases, you might want interact directly with appchain logic to setup the environment or query appchain's state.
Module wrappers provides convenient functions to interact with the appchain's module.

Let's try interact with `Gamm` module:

```rust
use cosmwasm_std::Coin;
use merlin_test_tube::{Account, Module, MerlinTestApp, Gamm};

let app = MerlinTestApp::default();
let alice = app
    .init_account(&[
        Coin::new(1_000_000_000_000, "uatom"),
        Coin::new(1_000_000_000_000, "ufury"),
    ])
    .unwrap();

// create Gamm Module Wrapper
let gamm = Gamm::new(&app);

// create balancer pool with basic configuration
let pool_liquidity = vec![Coin::new(1_000, "uatom"), Coin::new(1_000, "ufury")];
let pool_id = gamm
    .create_basic_pool(&pool_liquidity, &alice)
    .unwrap()
    .data
    .pool_id;

// query pool and assert if the pool is created successfully
let pool = gamm.query_pool(pool_id).unwrap();
assert_eq!(
    pool_liquidity
        .into_iter()
        .map(|c| c.into())
        .collect::<Vec<merlin_std::types::cosmos::base::v1beta1::Coin>>(),
    pool.pool_assets
        .into_iter()
        .map(|a| a.token.unwrap())
        .collect::<Vec<merlin_std::types::cosmos::base::v1beta1::Coin>>(),
);
```

## Custom Module Wrapper

You might not find wrapper you want to use or the provided wrapper is too verbose. Good new is, it's trivial to create your own wrapper easily.

Here is how you can redefine `Gamm` module wrapper as a library user:

```rust
use merlin_std::types::merlin::gamm::{
    poolmodels::balancer::v1beta1::{MsgCreateBalancerPool, MsgCreateBalancerPoolResponse},
};
use merlin_std::types::merlin::gamm::v2::{QuerySpotPriceRequest, QuerySpotPriceResponse};

use merlin_test_tube::{fn_execute, fn_query};
use merlin_test_tube::{Module, Runner};


// Boilerplate code, copy and rename should just do the trick
pub struct Gamm<'a, R: Runner<'a>> {
    runner: &'a R,
}

impl<'a, R: Runner<'a>> Module<'a, R> for Gamm<'a, R> {
    fn new(runner: &'a R) -> Self {
        Self { runner }
    }
}
// End Boilerplate code

impl<'a, R> Gamm<'a, R>
where
    R: Runner<'a>,
{
    // macro for creating execute function
    fn_execute! {
        // (pub)? <fn_name>: <request_type> => <response_type>
        pub create_balancer_pool: MsgCreateBalancerPool => MsgCreateBalancerPoolResponse
    }

    // macro for creating query function
    fn_query! {
        // (pub)? <fn_name> [<method_path>]: <request_type> => <response_type>
        pub query_spot_price ["/merlin.gamm.v2.Query/SpotPrice"]: QuerySpotPriceRequest => QuerySpotPriceResponse
    }
}
```

If the macro generated function is not good enough for you, you write your own function manually.
See [module directory](https://github.com/merlins-labs/merlin-rust/tree/main/packages/merlin-test-tube/src/module) for more inspiration.

## Versioning

The version of merlin-test-tube is determined by the versions of its dependencies, merlin and test-tube, as well as its own changes. The version is represented in the format A.B.C, where:

- A is the major version of merlin,
- B is the minor version of test-tube,
- C is the patch number of merlin-test-tube itself.

When a new version of merlin is released and contains breaking changes, we will also release breaking changes from test-tube if any and increment the major version of merlin-test-tube. This way, it's clear that the new version of merlin-test-tube is not backwards-compatible with previous versions.

When adding a new feature to merlin-test-tube that is backward-compatible, the minor version number will be incremented.

When fixing bugs or making other changes that are `merlin-test-tube` specific and backward-compatible, the patch number will be incremented.

Please review the upgrade guide for upgrading the package, in case of breaking changes

It is important to note that we track the version of the package independent of the version of dependencies.
