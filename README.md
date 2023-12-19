# Verify Contracts • [![CI](https://github.com/transmissions11/foundry-template/actions/workflows/tests.yml/badge.svg)](https://github.com/transmissions11/foundry-template/actions/workflows/tests.yml)

See the [developer docs](https://docs.verifymedia.com) for more!

## Contributing

You will need a copy of [Foundry](https://github.com/foundry-rs/foundry) installed before proceeding. See the [installation guide](https://github.com/foundry-rs/foundry#installation) for details.

### Setup

```sh
forge install
```

### Run Tests

```sh
forge test
```

### Update Gas Snapshots

```sh
forge snapshot
```

## Deployment

Instructions for deployment are in the `./script` dir. This includes 
instructions for deploying and verifying the smart contracts here. 

You must create a `.env` file in the root directory of this project. Follow
the `.envtemplate` for filling out the values needed there.   
