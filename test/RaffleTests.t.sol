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

        vm.warp(3700); // advance 1 hour and 1 minute from now

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
        uint256 lowFee = 99999; // 0.099999 USDC (6 decimals)
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

    /* Enter Raffle Tests */

    function test_EnterRaffleWithGuess() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 guess = block.timestamp + 3600; // 1 hour in future
        uint256 roundedGuess = raffle.roundDownToMinute(guess);

        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(guess, 1);

        assertEq(raffle.getGuesses(1, roundedGuess), entrant1);
        assertEq(raffle.getPrizePool(1), ENTRY_FEE);
        assertEq(raffle.getIsRaffleOpen(1), true);
        assertEq(raffle.getAccruedProtocolFee(), 0);
    }

    function test_EnterRaffleRevertsWithNonExistentRaffle() public {
        uint256 guess = block.timestamp + 3600;
        vm.prank(entrant1);
        vm.expectRevert(FiftyFiftyRaffle.RaffleDoesNotExist.selector);
        raffle.enterRaffleWithGuess(guess, 1);
    }

    function test_EnterRaffleRevertsWhenRaffleClosed() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(owner);
        raffle.closeRaffle(1);

        uint256 guess = block.timestamp + 3600;
        vm.prank(entrant1);
        vm.expectRevert(FiftyFiftyRaffle.RaffleIsClosed.selector);
        raffle.enterRaffleWithGuess(guess, 1);
    }

    function test_EnterRaffleRevertsWithEarlyGuess() public {
        vm.warp(3700); // advance 1 hour and 1 minute from now
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 earlyGuess = block.timestamp - 3600; // 1 hour in future

        vm.prank(entrant1);
        vm.expectRevert(FiftyFiftyRaffle.GuessTimestampTooLow.selector);
        raffle.enterRaffleWithGuess(earlyGuess, 1);
    }

    function test_EnterRaffleRevertsWithDuplicateGuess() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 guess = block.timestamp + 3600;

        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(guess, 1);

        vm.prank(entrant2);
        vm.expectRevert(FiftyFiftyRaffle.GuessAlreadyEntered.selector);
        raffle.enterRaffleWithGuess(guess, 1);
    }

    function test_EnterRaffleRoundsDownToMinute() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 guessWithSeconds = block.timestamp + 3600 + 30; // 1 hour forward + 30 seconds

        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(guessWithSeconds, 1);

        uint256 roundedGuess = raffle.roundDownToMinute(guessWithSeconds);
        assertEq(raffle.getGuesses(1, roundedGuess), entrant1);
    }

    function test_EnterRaffleUpdatesPrizePool() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 guess = block.timestamp + 3600;

        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(guess, 1);
        assertEq(raffle.getPrizePool(1), ENTRY_FEE);

        vm.prank(entrant2);
        raffle.enterRaffleWithGuess(guess - 60, 1);
        assertEq(raffle.getPrizePool(1), ENTRY_FEE * 2);
    }

    function test_EnterRaffleEmitsEvent() public {
        vm.warp(3700); // advance 1 hour and 1 minute from now
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 guess = block.timestamp + 3600;
        uint256 roundedGuess = raffle.roundDownToMinute(guess);

        vm.prank(entrant1);
        vm.expectEmit(true, true, false, false);
        emit FiftyFiftyRaffle.RaffleEntered(1, entrant1, roundedGuess);
        raffle.enterRaffleWithGuess(guess, 1);
    }

    /* Close Raffle Tests */

    function test_CloseRaffleByOwner() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(owner);
        raffle.closeRaffle(1);
        assertFalse(raffle.getIsRaffleOpen(1));
    }

    function test_CloseRaffleByBeneficiary() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(beneficiary);
        raffle.closeRaffle(1);
        assertFalse(raffle.getIsRaffleOpen(1));
    }

    function test_CloseRaffleRevertsWithNonExistentRaffle() public {
        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.RaffleDoesNotExist.selector);
        raffle.closeRaffle(1);
    }

    function test_CloseRaffleRevertsWhenNotAuthorized() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(user1);
        vm.expectRevert(FiftyFiftyRaffle.AddressNotAuthorized.selector);
        raffle.closeRaffle(1);
    }

    function test_CloseRaffleRevertsWhenAlreadyClosed() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(owner);
        raffle.closeRaffle(1);
        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.RaffleIsClosed.selector);
        raffle.closeRaffle(1);
    }

    function test_CloseRaffleEmitsEvent() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(block.timestamp + 3600, 1);
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit FiftyFiftyRaffle.RaffleClosed(1);
        raffle.closeRaffle(1);
    }

    /* Set Winning Timestamp Tests */

    function test_SetWinningTimestampByOwner() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        uint256 winningTime = raffle.getStartTimestamp(1) + 120;
        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTime);
        assertEq(raffle.getWinningTimestamp(1), raffle.roundDownToMinute(winningTime));
        assertFalse(raffle.getIsRaffleOpen(1));
    }

    function test_SetWinningTimestampByBeneficiary() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        uint256 winningTime = raffle.getStartTimestamp(1) + 120;
        vm.prank(beneficiary);
        raffle.setWinningTimestamp(1, winningTime);
        assertEq(raffle.getWinningTimestamp(1), raffle.roundDownToMinute(winningTime));
        assertFalse(raffle.getIsRaffleOpen(1));
    }

    function test_SetWinningTimestampRevertsWithNonExistentRaffle() public {
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        uint256 winningTime = raffle.getStartTimestamp(1) + 120;
        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.RaffleDoesNotExist.selector);
        raffle.setWinningTimestamp(1, winningTime);
    }

    function test_SetWinningTimestampRevertsWhenNotAuthorized() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        uint256 winningTime = raffle.getStartTimestamp(1) + 120;
        vm.prank(user1);
        vm.expectRevert(FiftyFiftyRaffle.AddressNotAuthorized.selector);
        raffle.setWinningTimestamp(1, winningTime);
    }

    function test_SetWinningTimestampRevertsWithFutureTimestamp() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 futureTime = block.timestamp + 3600;
        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.WinningTimestampTooHigh.selector);
        raffle.setWinningTimestamp(1, futureTime);
    }

    function test_SetWinningTimestampRevertsWithEarlyTimestamp() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 earlyTime = 60;
        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.WinningTimestampTooLow.selector);
        raffle.setWinningTimestamp(1, earlyTime);
    }

    function test_SetWinningTimestampRevertsWhenAlreadySet() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        uint256 winningTime = raffle.getStartTimestamp(1) + 120;
        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTime);
        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.WinningTimestampAlreadySet.selector);
        raffle.setWinningTimestamp(1, winningTime);
    }

    function test_SetWinningTimestampRoundsDownToMinute() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        uint256 winningTimeWithSeconds = raffle.getStartTimestamp(1) + 120 + 30; // 1 hour ago + 30 seconds
        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTimeWithSeconds);
        assertEq(raffle.getWinningTimestamp(1), raffle.roundDownToMinute(winningTimeWithSeconds));
    }

    function test_SetWinningTimestampEmitsEvent() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        uint256 winningTime = raffle.getStartTimestamp(1) + 120;
        uint256 roundedTime = raffle.roundDownToMinute(winningTime);
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit FiftyFiftyRaffle.WinningTimestampSet(1, roundedTime);
        raffle.setWinningTimestamp(1, winningTime);
    }

    /* Distribute Prize Tests */

    function test_DistributePrize() public {
        // Setup raffle and entries
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        uint256 guess = block.timestamp + 3600;
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(guess, 1);
        vm.prank(entrant2);
        raffle.enterRaffleWithGuess(guess - 60, 1);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now

        // Close raffle and set winning timestamp
        vm.prank(owner);
        raffle.setWinningTimestamp(1, guess);

        // Get initial balances
        uint256 initialWinnerBalance = mockToken.balanceOf(entrant1);
        uint256 initialBeneficiaryBalance = mockToken.balanceOf(beneficiary);
        uint256 initialContractBalance = mockToken.balanceOf(address(raffle));

        // Distribute prize
        raffle.distributePrize(1);

        // Calculate expected payouts
        uint256 totalPrize = ENTRY_FEE * 2;
        uint256 protocolFeeAmount = (totalPrize * PROTOCOL_FEE) / 10000;
        uint256 payout = (totalPrize - protocolFeeAmount) / 2;

        // Verify balances
        assertEq(mockToken.balanceOf(entrant1), initialWinnerBalance + payout);
        assertEq(mockToken.balanceOf(beneficiary), initialBeneficiaryBalance + payout);
        assertEq(mockToken.balanceOf(address(raffle)), initialContractBalance - (payout + payout));
        assertEq(raffle.getPrizePool(1), 0);
        assertEq(raffle.getAccruedProtocolFee(), protocolFeeAmount);
    }

    function test_DistributePrizeRevertsWithNonExistentRaffle() public {
        vm.expectRevert(FiftyFiftyRaffle.RaffleDoesNotExist.selector);
        raffle.distributePrize(1);
    }

    function test_DistributePrizeRevertsWhenRaffleOpen() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.expectRevert(FiftyFiftyRaffle.RaffleIsNotClosed.selector);
        raffle.distributePrize(1);
    }

    function test_DistributePrizeRevertsWhenWinningTimestampNotSet() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(owner);
        raffle.closeRaffle(1);
        vm.expectRevert(FiftyFiftyRaffle.RaffleIsNotClosed.selector);
        raffle.distributePrize(1);
    }

    function test_DistributePrizeRevertsWithZeroPrizePool() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        vm.prank(owner);
        raffle.setWinningTimestamp(1, block.timestamp - 1700);
        vm.expectRevert(FiftyFiftyRaffle.PrizePoolIsZero.selector);
        raffle.distributePrize(1);
    }

    function test_DistributePrizeRevertsWhenNoWinnerFound() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(block.timestamp + 3600, 1);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        vm.prank(owner);
        raffle.setWinningTimestamp(1, block.timestamp - 1800);
        vm.expectRevert(FiftyFiftyRaffle.NoWinnerFound.selector);
        raffle.distributePrize(1);
    }

    function test_DistributePrizeWithExactMatch() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = block.timestamp + 3600;
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime, 1);

        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTime);

        uint256 initialWinnerBalance = mockToken.balanceOf(entrant1);
        raffle.distributePrize(1);

        uint256 protocolFeeAmount = (ENTRY_FEE * PROTOCOL_FEE) / 10000;
        uint256 payout = (ENTRY_FEE - protocolFeeAmount) / 2;
        assertEq(mockToken.balanceOf(entrant1), initialWinnerBalance + payout);
    }

    function test_DistributePrizeWithClosestMatch() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = block.timestamp + 3600;
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime - 120, 1); // 2 minutes before
        vm.prank(entrant2);
        raffle.enterRaffleWithGuess(winningTime - 60, 1); // 1 minute before (closest)
        uint256 prizePool = raffle.getPrizePool(1);

        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTime);

        uint256 initialWinnerBalance = mockToken.balanceOf(entrant2);
        raffle.distributePrize(1);

        uint256 protocolFeeAmount = (prizePool * PROTOCOL_FEE) / 10000;
        uint256 payout = (prizePool - protocolFeeAmount) / 2;
        assertEq(mockToken.balanceOf(entrant2), initialWinnerBalance + payout);
    }

    function test_DistributePrizeEmitsEvents() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = block.timestamp + 3600;
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime, 1);

        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTime);

        uint256 protocolFeeAmount = (ENTRY_FEE * PROTOCOL_FEE) / 10000;
        uint256 payout = (ENTRY_FEE - protocolFeeAmount) / 2;

        vm.expectEmit(true, true, false, false);
        emit FiftyFiftyRaffle.RaffleWon(1, entrant1, payout);
        vm.expectEmit(true, true, false, false);
        emit FiftyFiftyRaffle.BeneficiaryPaid(1, beneficiary, payout);
        raffle.distributePrize(1);
    }

    function test_DistributePrizeMultipleTimesReverts() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = block.timestamp + 3600;
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime, 1);

        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTime);

        raffle.distributePrize(1);
        vm.expectRevert(FiftyFiftyRaffle.PrizePoolIsZero.selector);
        raffle.distributePrize(1);
    }

    /* Manually Close Raffle Tests */

    function test_ManuallyCloseRaffle() public {
        // Setup raffle and entries
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = raffle.roundDownToMinute(block.timestamp + 3600);
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime, 1);
        vm.prank(entrant2);
        raffle.enterRaffleWithGuess(winningTime - 60, 1);
        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now

        // Get initial balances
        uint256 initialWinnerBalance = mockToken.balanceOf(entrant1);
        uint256 initialBeneficiaryBalance = mockToken.balanceOf(beneficiary);
        uint256 initialContractBalance = mockToken.balanceOf(address(raffle));

        // Manually close raffle
        vm.prank(owner);
        raffle.manuallyCloseRaffle(1, winningTime);

        // Calculate expected payouts
        uint256 totalPrize = ENTRY_FEE * 2;
        uint256 protocolFeeAmount = (totalPrize * PROTOCOL_FEE) / 10000;
        uint256 payout = (totalPrize - protocolFeeAmount) / 2;

        // Verify balances and state
        assertEq(mockToken.balanceOf(entrant1), initialWinnerBalance + payout);
        assertEq(mockToken.balanceOf(beneficiary), initialBeneficiaryBalance + payout);
        assertEq(mockToken.balanceOf(address(raffle)), protocolFeeAmount);
        assertEq(mockToken.balanceOf(address(raffle)), initialContractBalance - (payout + payout));
        assertEq(raffle.getPrizePool(1), 0);
        assertEq(raffle.getAccruedProtocolFee(), protocolFeeAmount);
        assertFalse(raffle.getIsRaffleOpen(1));
        assertEq(raffle.getWinningTimestamp(1), raffle.roundDownToMinute(winningTime));
    }

    function test_ManuallyCloseRaffleRevertsWithNonExistentRaffle() public {
        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.RaffleDoesNotExist.selector);
        raffle.manuallyCloseRaffle(1, block.timestamp + 3600);
    }

    function test_ManuallyCloseRaffleRevertsWhenNotOwner() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(block.timestamp + 3600, 1);

        vm.prank(beneficiary);
        vm.expectRevert();
        raffle.manuallyCloseRaffle(1, block.timestamp + 3600);
    }

    function test_ManuallyCloseRaffleRevertsWithZeroPrizePool() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.PrizePoolIsZero.selector);
        raffle.manuallyCloseRaffle(1, block.timestamp + 3600);
    }

    function test_ManuallyCloseRaffleRevertsWhenNoWinnerFound() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(block.timestamp + 3600, 1);

        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.NoWinnerFound.selector);
        raffle.manuallyCloseRaffle(1, block.timestamp + 7200); // Different timestamp
    }

    function test_ManuallyCloseRaffleEmitsEvents() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = block.timestamp + 3600;
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime, 1);

        uint256 protocolFeeAmount = (ENTRY_FEE * PROTOCOL_FEE) / 10000;
        uint256 payout = (ENTRY_FEE - protocolFeeAmount) / 2;
        uint256 roundedTime = raffle.roundDownToMinute(winningTime);

        vm.warp(block.timestamp + 3700); // advance 1 hour and 1 minute from now
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit FiftyFiftyRaffle.WinningTimestampSet(1, roundedTime);
        vm.expectEmit(true, true, false, false);
        emit FiftyFiftyRaffle.RaffleWon(1, entrant1, payout);
        vm.expectEmit(true, true, false, false);
        emit FiftyFiftyRaffle.BeneficiaryPaid(1, beneficiary, payout);
        raffle.manuallyCloseRaffle(1, roundedTime);
    }

    function test_ManuallyCloseRaffleClosesRaffle() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = block.timestamp + 3600;
        uint256 roundedTime = raffle.roundDownToMinute(winningTime);
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime, 1);

        assertTrue(raffle.getIsRaffleOpen(1));
        vm.prank(owner);
        raffle.manuallyCloseRaffle(1, roundedTime);
        assertFalse(raffle.getIsRaffleOpen(1));
    }

    function test_ManuallyCloseRaffleOnlyWorksOnce() public {
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = block.timestamp + 3600;
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime, 1);

        uint256 roundedTime = raffle.roundDownToMinute(winningTime);
        vm.prank(owner);
        raffle.manuallyCloseRaffle(1, roundedTime);
        vm.prank(owner);
        vm.expectRevert(FiftyFiftyRaffle.PrizePoolIsZero.selector);
        raffle.manuallyCloseRaffle(1, roundedTime);
    }

    /* Claim Protocol Fee Tests */

    function test_ClaimProtocolFee() public {
        // Setup raffle and generate protocol fees
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = block.timestamp + 3600;
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime, 1);
        vm.prank(entrant2);
        raffle.enterRaffleWithGuess(winningTime - 60, 1);

        vm.warp(block.timestamp + 3700);
        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTime);
        raffle.distributePrize(1);

        // Get initial balances
        uint256 initialOwnerBalance = mockToken.balanceOf(owner);
        uint256 initialContractBalance = mockToken.balanceOf(address(raffle));
        uint256 accruedFee = raffle.getAccruedProtocolFee();

        // Claim protocol fee
        vm.prank(owner);
        raffle.claimProtocolFee();

        // Verify balances
        assertEq(mockToken.balanceOf(owner), initialOwnerBalance + accruedFee);
        assertEq(mockToken.balanceOf(address(raffle)), initialContractBalance - accruedFee);
        assertEq(raffle.getAccruedProtocolFee(), 0);
    }

    function test_ClaimProtocolFeeRevertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        raffle.claimProtocolFee();
    }

    function test_ClaimProtocolFeeWithZeroAccruedFee() public {
        uint256 initialOwnerBalance = mockToken.balanceOf(owner);
        vm.prank(owner);
        raffle.claimProtocolFee();
        assertEq(mockToken.balanceOf(owner), initialOwnerBalance);
        assertEq(raffle.getAccruedProtocolFee(), 0);
    }

    function test_ClaimProtocolFeeMultipleTimes() public {
        // Generate protocol fees from multiple raffles
        raffle.createRaffle(beneficiary, ENTRY_FEE);
        uint256 winningTime = block.timestamp + 3600;
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(winningTime, 1);

        vm.warp(block.timestamp + 3700);
        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTime);
        raffle.distributePrize(1);

        vm.prank(owner);
        raffle.claimProtocolFee();

        // Create second raffle and generate more fees
        raffle.createRaffle(entrant1, ENTRY_FEE);
        uint256 winningTime2 = block.timestamp + 3600;
        vm.prank(entrant2);
        raffle.enterRaffleWithGuess(winningTime2, 2);

        vm.warp(block.timestamp + 3700);
        vm.prank(owner);
        raffle.setWinningTimestamp(2, winningTime2);
        raffle.distributePrize(2);

        vm.prank(owner);
        raffle.claimProtocolFee();

        assertEq(raffle.getAccruedProtocolFee(), 0);
    }

    /* Fuzzing Tests */

    function test_Fuzz_MultipleEntrantsWithRandomGuesses(uint256 guess1, uint256 guess2, uint256 guess3) public {
        // Bound the guesses to reasonable ranges
        vm.assume(guess1 >= block.timestamp + 60 && guess1 <= block.timestamp + 86400); // 1 minute to 1 day
        vm.assume(guess2 >= block.timestamp + 60 && guess2 <= block.timestamp + 86400);
        vm.assume(guess3 >= block.timestamp + 60 && guess3 <= block.timestamp + 86400);
        vm.assume(
            raffle.roundDownToMinute(guess1) != raffle.roundDownToMinute(guess2)
                && raffle.roundDownToMinute(guess1) != raffle.roundDownToMinute(guess3)
                && raffle.roundDownToMinute(guess2) != raffle.roundDownToMinute(guess3)
        ); // Ensure unique guesses

        // Create raffle
        raffle.createRaffle(beneficiary, ENTRY_FEE);

        // All three entrants enter with their guesses
        vm.prank(entrant1);
        raffle.enterRaffleWithGuess(guess1, 1);

        vm.prank(entrant2);
        raffle.enterRaffleWithGuess(guess2, 1);

        vm.prank(entrant3);
        raffle.enterRaffleWithGuess(guess3, 1);

        // Verify all entries were recorded
        uint256 roundedGuess1 = raffle.roundDownToMinute(guess1);
        uint256 roundedGuess2 = raffle.roundDownToMinute(guess2);
        uint256 roundedGuess3 = raffle.roundDownToMinute(guess3);

        assertEq(raffle.getGuesses(1, roundedGuess1), entrant1);
        assertEq(raffle.getGuesses(1, roundedGuess2), entrant2);
        assertEq(raffle.getGuesses(1, roundedGuess3), entrant3);

        // Verify prize pool accumulated correctly
        assertEq(raffle.getPrizePool(1), ENTRY_FEE * 3);

        // Set winning timestamp and distribute prize
        uint256 winningTime = block.timestamp + 86300;
        vm.warp(winningTime + 3600); // Advance time

        vm.prank(owner);
        raffle.setWinningTimestamp(1, winningTime);

        // Find the winner (closest to winning time)
        address winner = raffle.getWinner(1);
        assertTrue(winner == entrant1 || winner == entrant2 || winner == entrant3);

        // Distribute prize
        uint256 initialWinnerBalance = mockToken.balanceOf(winner);
        raffle.distributePrize(1);

        // Verify winner received payout
        uint256 totalPrize = ENTRY_FEE * 3;
        uint256 protocolFeeAmount = (totalPrize * PROTOCOL_FEE) / 10000;
        uint256 payout = (totalPrize - protocolFeeAmount) / 2;

        assertEq(mockToken.balanceOf(winner), initialWinnerBalance + payout);
        assertEq(raffle.getPrizePool(1), 0);
        assertEq(raffle.getAccruedProtocolFee(), protocolFeeAmount);
        assertFalse(raffle.getIsRaffleOpen(1));
    }
}
