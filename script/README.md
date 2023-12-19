# Scripts of Deployment

## How To Use

Ensure that all variables in .env are set. There is a template of what needs to be included in .envtemplate, *see the README.md in the root directory for more info*

Run the script (without broadcast) to check functionaility against chain state.

`forge script ./script/${SCRIPT_NAME}.s.sol --rpc-url ${NETWORK}`

where ${SCRIPT_NAME}.s.sol is the script that you want to run and network is either `mumbai` or `polgon`

Example: `forge script ./script/deploy.s.sol --rpc-url mumbai`


