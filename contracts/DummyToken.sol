// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DummyToken is ERC20 {
    constructor() ERC20("DummyToken", "DMT") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
