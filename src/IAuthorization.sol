// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IAuthorization {
    function auth(bytes32 id, address user) external view returns (bool isAuthorised);
}
