// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {FiftyFiftyRaffle} from "../src/FiftyFiftyRaffle.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {DeployRaffle} from "../script/DeployRaffle.s.sol";

contract RaffleTest is Test {
    FiftyFiftyRaffle public raffle;
    ERC20Mock public mockToken;

    // Test addresses
    address public owner;
    address public beneficiary = makeAddr("beneficiary");
    address public entrant1 = makeAddr("entrant1");
    address public entrant2 = makeAddr("entrant2");
    address public entrant3 = makeAddr("entrant3");
    address public user1 = makeAddr("user1");

    // Test constants
    uint256 public constant PROTOCOL_FEE = 50; // 0.5%
    uint256 public constant ENTRY_FEE = 5e6;
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000000e6;

    // Events for testing

    function setUp() public {
        // Deploy contracts
        DeployRaffle deployer = new DeployRaffle();
        address usdcTokenAddress;
        (raffle, usdcTokenAddress) = deployer.run();
        mockToken = ERC20Mock(usdcTokenAddress);
        owner = raffle.owner();

        // Mint tokens to test addresses
        mockToken.mint(beneficiary, INITIAL_TOKEN_SUPPLY);
        mockToken.mint(entrant1, INITIAL_TOKEN_SUPPLY);
        mockToken.mint(entrant2, INITIAL_TOKEN_SUPPLY);
        mockToken.mint(entrant3, INITIAL_TOKEN_SUPPLY);
        mockToken.mint(user1, INITIAL_TOKEN_SUPPLY);

        // Approve raffle contract to spend tokens
        vm.prank(beneficiary);
        mockToken.approve(address(raffle), type(uint256).max);

        vm.prank(entrant1);
        mockToken.approve(address(raffle), type(uint256).max);

        vm.prank(entrant2);
        mockToken.approve(address(raffle), type(uint256).max);

        vm.prank(entrant3);
        mockToken.approve(address(raffle), type(uint256).max);

        vm.prank(user1);
        mockToken.approve(address(raffle), type(uint256).max);
    }
}
