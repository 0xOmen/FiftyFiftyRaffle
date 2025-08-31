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

    /* Constructor and Deployment Tests */

    function test_ConstructorSetsTokenAddress() public view {
        assertEq(raffle.getTokenAddress(), address(mockToken));
    }

    function test_ConstructorSetsProtocolFee() public view {
        assertEq(raffle.getProtocolFee(), PROTOCOL_FEE);
    }

    function test_ConstructorSetsOwner() public view {
        address defaultAnvilAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        assertEq(raffle.owner(), defaultAnvilAddress);
    }

    function test_ConstructorInitializesRaffleNumberToZero() public view {
        assertEq(raffle.getRaffleNumber(), 0);
    }

    function test_ConstructorInitializesAccruedProtocolFeeToZero() public view {
        assertEq(raffle.getAccruedProtocolFee(), 0);
    }

    /* Set Fee Tests */

    function test_SetProtocolFee() public {
        uint256 newFee = 100; // 1%
        vm.prank(owner);
        raffle.setProtocolFee(newFee);
        assertEq(raffle.getProtocolFee(), newFee);
    }

    function test_SetProtocolFeeRevertsWhenNotOwner() public {
        uint256 newFee = 100;
        vm.prank(user1);
        vm.expectRevert();
        raffle.setProtocolFee(newFee);
    }

    /* Create Raffle Tests */

    function test_CreateRaffle() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        assertEq(raffle.getRaffleNumber(), 1);
        assertEq(raffle.getBeneficiary(1), beneficiary);
        assertEq(raffle.getEntryFee(1), ENTRY_FEE);
        assertEq(raffle.getPrizePool(1), 0);
        assertTrue(raffle.getIsRaffleOpen(1));
    }

    function test_CreateRaffleRevertsWithZeroBeneficiary() public {
        vm.expectRevert(FiftyFiftyRaffle.BeneficiaryCannotBeZeroAddress.selector);
        raffle.createRaffle(address(0), ENTRY_FEE);
    }

    function test_CreateRaffleRevertsWithLowEntryFee() public {
        uint256 lowFee = 990000; // 0.99 USDC (6 decimals)
        vm.expectRevert(FiftyFiftyRaffle.EntryFeeTooLow.selector);
        raffle.createRaffle(beneficiary, lowFee);
    }

    function test_CreateMultipleRaffles() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        raffle.createRaffle(entrant1, ENTRY_FEE * 2);

        assertEq(raffle.getRaffleNumber(), 2);
        assertEq(raffle.getBeneficiary(1), beneficiary);
        assertEq(raffle.getBeneficiary(2), entrant1);
        assertEq(raffle.getEntryFee(1), ENTRY_FEE);
        assertEq(raffle.getEntryFee(2), ENTRY_FEE * 2);
    }
}
