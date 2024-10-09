// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";

contract FlashLoanReceiver is IERC3156FlashBorrower {
  address governance;
  uint256 public actionId;
  
  constructor(address _governance) {
    governance = _governance;
  }

  function onFlashLoan(
      address,
      address token,
      uint256 amount,
      uint256,
      bytes memory data
  ) external returns (bytes32) {
    DamnValuableVotes(token).delegate(address(this));
    (bool success, bytes memory result) = governance.call(data);
    require(success, "call failed");
    actionId = abi.decode(result, (uint256));
    IERC20(token).approve(msg.sender, amount);
    return keccak256("ERC3156FlashBorrower.onFlashLoan");
  }
}