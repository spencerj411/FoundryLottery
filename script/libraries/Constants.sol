// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library CONSTANTS {
    // BLOCKCHAIN IDS CONSTANTS
    uint256 public constant SEPOLIA_ID = 11155111;
    uint256 public constant ANVIL_ID = 31337;

    // MOCK CONSTANTS
    uint96 public constant BASE_FEE = 0.25 ether;
    uint96 public constant GAS_PRICE_LINK = 1e9;
    int256 public constant WEI_PER_UNIT_LINK = 4e15;

    // HELPER CONFIG CONSTANTS
    uint256 public constant ENTRACE_FEE = 0.01 ether;
    uint256 public constant INTERVAL = 60; // seconds
    uint32 public constant CALLBACK_GAS_LIMIT = 500_000;
    uint96 public constant LINK_FUND_AMOUNT = 3 ether; // 3 LINK
}
