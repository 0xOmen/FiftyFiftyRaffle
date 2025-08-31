// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FiftyFiftyRaffle
 * @author 0x-Omen.eth
 *
 * FiftyFiftyRaffle is a contract that allows users to participate in a raffle that disperses
 * 50% of the winnings to the winner and 50% to the beneficiary.
 *
 */
contract FiftyFiftyRaffle is Ownable {
    error BeneficiaryCannotBeZeroAddress();
    error RaffleDoesNotExist();
    error GuessTimestampTooLow();
    error GuessTimestampTooHigh();
    error GuessAlreadyEntered();
    error EntryFeeTooLow();
    error RaffleIsClosed();
    error AddressNotAuthorized();
    error WinningTimestampAlreadySet();
    error WinningTimestampTooHigh();
    error RaffleIsNotClosed();
    error NoWinnerFound();
    error PayoutOverflow();
    error PrizePoolIsZero();
    error WinningTimestampTooLow();
    /* Events */

    event WinningTimestampSet(uint256 indexed raffleNumber, uint256 winningTimestamp);
    event RaffleEntered(uint256 indexed raffleNumber, address indexed entrant, uint256 guess);
    event RaffleWon(uint256 indexed raffleNumber, address indexed winner, uint256 payout);
    event RaffleClosed(uint256 indexed raffleNumber);
    event BeneficiaryPaid(uint256 indexed raffleNumber, address indexed beneficiary, uint256 payout);

    /* State Variables */

    // USDC token address
    address private immutable i_tokenAddress;
    // Protocol fee percentage in basis points; 10000 = 100% and 50 = 0.5%
    uint256 private protocolFee;
    // Raffle number to managing accounting of multiple raffles
    uint256 private raffleNumber;
    mapping(uint256 => bool) private isRaffleOpen;
    // Mapping of raffle number to guess
    // guesses[raffleNumber][guess] where guess is a unix timestamp that maps to what address submitted that guess
    mapping(uint256 => mapping(uint256 => address)) private guesses;
    mapping(uint256 => uint256) private winningTimestamp;
    mapping(uint256 => address) private beneficiary;
    mapping(uint256 => uint256) private entryFee;
    mapping(uint256 => uint256) private prizePool;
    mapping(uint256 => uint256) private startTimestamp;
    uint256 private accruedProtocolFee;

    constructor(address tokenAddress, uint256 _protocolFee) Ownable(msg.sender) {
        i_tokenAddress = tokenAddress;
        protocolFee = _protocolFee;
        raffleNumber = 0;
        accruedProtocolFee = 0;
    }

    function setProtocolFee(uint256 newProtocolFee) external onlyOwner {
        protocolFee = newProtocolFee;
    }

    function createRaffle(address _beneficiary, uint256 _entryFee) external {
        if (_beneficiary == address(0)) {
            revert BeneficiaryCannotBeZeroAddress();
        }
        if (_entryFee <= 1000000) {
            revert EntryFeeTooLow();
        }
        raffleNumber++;
        startTimestamp[raffleNumber] = block.timestamp;
        isRaffleOpen[raffleNumber] = true;
        beneficiary[raffleNumber] = _beneficiary;
        prizePool[raffleNumber] = 0;
        entryFee[raffleNumber] = _entryFee;
    }

    function enterRaffleWithGuess(uint256 guess, uint256 _raffleNumber) external {
        if (_raffleNumber > raffleNumber) {
            revert RaffleDoesNotExist();
        }
        if (!isRaffleOpen[_raffleNumber]) {
            revert RaffleIsClosed();
        }
        guess = roundDownToMinute(guess);
        if (guess < startTimestamp[_raffleNumber]) {
            revert GuessTimestampTooLow();
        }
        // Check if the guess has already been entered
        if (guesses[_raffleNumber][guess] != address(0)) {
            revert GuessAlreadyEntered();
        }

        guesses[_raffleNumber][guess] = msg.sender;

        // Transfer the entry fee to the contract
        uint256 _entryFee = entryFee[_raffleNumber];
        prizePool[_raffleNumber] += _entryFee;
        emit RaffleEntered(_raffleNumber, msg.sender, guess);
        IERC20(i_tokenAddress).transferFrom(msg.sender, address(this), _entryFee);
    }

    function closeRaffle(uint256 _raffleNumber) public {
        if (_raffleNumber > raffleNumber) {
            revert RaffleDoesNotExist();
        }
        if (msg.sender != beneficiary[_raffleNumber] && msg.sender != owner()) {
            revert AddressNotAuthorized();
        }
        if (!isRaffleOpen[_raffleNumber]) {
            revert RaffleIsClosed();
        }

        emit RaffleClosed(_raffleNumber);
        isRaffleOpen[_raffleNumber] = false;
    }

    function setWinningTimestamp(uint256 _raffleNumber, uint256 _winningTimestamp) public {
        if (_raffleNumber > raffleNumber) {
            revert RaffleDoesNotExist();
        }
        if (msg.sender != beneficiary[_raffleNumber] && msg.sender != owner()) {
            revert AddressNotAuthorized();
        }
        if (_winningTimestamp >= block.timestamp) {
            revert WinningTimestampTooHigh();
        }
        if (winningTimestamp[_raffleNumber] != 0) {
            revert WinningTimestampAlreadySet();
        }
        if (_winningTimestamp < startTimestamp[_raffleNumber]) {
            revert WinningTimestampTooLow();
        }
        winningTimestamp[_raffleNumber] = roundDownToMinute(_winningTimestamp);
        isRaffleOpen[_raffleNumber] = false;
        emit WinningTimestampSet(_raffleNumber, roundDownToMinute(_winningTimestamp));
    }

    function distributePrize(uint256 _raffleNumber) public {
        uint256 _prizePool = prizePool[_raffleNumber];
        if (_raffleNumber > raffleNumber) {
            revert RaffleDoesNotExist();
        }
        if (isRaffleOpen[_raffleNumber] || winningTimestamp[_raffleNumber] == 0) {
            revert RaffleIsNotClosed();
        }
        if (_prizePool == 0) {
            revert PrizePoolIsZero();
        }

        address winner = getWinner(_raffleNumber);
        if (winner == address(0)) {
            revert NoWinnerFound();
        }
        //calculate protocol fee amount
        uint256 protocolFeeAmount = (_prizePool * protocolFee) / 10000;
        uint256 payout = (_prizePool - protocolFeeAmount) / 2;
        accruedProtocolFee += protocolFeeAmount;
        if (_prizePool < protocolFeeAmount + payout + payout) {
            revert PayoutOverflow();
        }
        prizePool[_raffleNumber] = 0;

        emit RaffleWon(_raffleNumber, winner, payout);
        emit BeneficiaryPaid(_raffleNumber, beneficiary[_raffleNumber], payout);
        IERC20(i_tokenAddress).transfer(winner, payout);
        IERC20(i_tokenAddress).transfer(beneficiary[_raffleNumber], payout);
    }

    function manuallyCloseRaffle(uint256 _raffleNumber, uint256 _winningTimestamp) external onlyOwner {
        if (_raffleNumber > raffleNumber) {
            revert RaffleDoesNotExist();
        }
        if (prizePool[_raffleNumber] == 0) {
            revert PrizePoolIsZero();
        }

        address winner = guesses[_raffleNumber][_winningTimestamp];
        if (winner == address(0)) {
            revert NoWinnerFound();
        }
        isRaffleOpen[_raffleNumber] = false;
        winningTimestamp[_raffleNumber] = roundDownToMinute(_winningTimestamp);
        emit WinningTimestampSet(_raffleNumber, roundDownToMinute(_winningTimestamp));
        //calculate protocol fee amount
        uint256 protocolFeeAmount = (prizePool[_raffleNumber] * protocolFee) / 10000;
        uint256 payout = (prizePool[_raffleNumber] - protocolFeeAmount) / 2;
        accruedProtocolFee += protocolFeeAmount;
        prizePool[_raffleNumber] = 0;

        emit RaffleWon(_raffleNumber, winner, payout);
        emit BeneficiaryPaid(_raffleNumber, beneficiary[_raffleNumber], payout);
        IERC20(i_tokenAddress).transfer(winner, payout);
        IERC20(i_tokenAddress).transfer(beneficiary[_raffleNumber], payout);
    }

    function claimProtocolFee() external onlyOwner {
        IERC20(i_tokenAddress).transfer(owner(), accruedProtocolFee);
        accruedProtocolFee = 0;
    }

    /**
     * @notice Rounds down a given timestamp to the nearest whole minute.
     * @param timestamp The timestamp to round down.
     * @return The rounded timestamp.
     */
    function roundDownToMinute(uint256 timestamp) public pure returns (uint256) {
        // Use modulo to get the number of seconds past the last full minute
        uint256 secondsPastMinute = timestamp % 60;

        // Subtract the seconds past the last full minute from the original timestamp
        return timestamp - secondsPastMinute;
    }

    function getWinner(uint256 _raffleNumber) public view returns (address) {
        // check if guesses[raffleNumber][winningTimestamp] has a value, if so return the address
        // if not, check every 60 second interval prior to the winning timestamp and return address when found
        uint256 _winningTimestamp = winningTimestamp[_raffleNumber];
        uint256 _startTimestamp = startTimestamp[_raffleNumber];
        if (guesses[_raffleNumber][_winningTimestamp] != address(0)) {
            return guesses[_raffleNumber][_winningTimestamp];
        }
        for (uint256 i = _winningTimestamp; i > _startTimestamp - 60; i -= 60) {
            if (guesses[_raffleNumber][i] != address(0)) {
                return guesses[_raffleNumber][i];
            }
        }
        return address(0);
    }

    /* Getter Functions */

    function getProtocolFee() public view returns (uint256) {
        return protocolFee;
    }

    function getAccruedProtocolFee() public view returns (uint256) {
        return accruedProtocolFee;
    }

    function getPrizePool(uint256 _raffleNumber) public view returns (uint256) {
        return prizePool[_raffleNumber];
    }

    function getEntryFee(uint256 _raffleNumber) public view returns (uint256) {
        return entryFee[_raffleNumber];
    }

    function getBeneficiary(uint256 _raffleNumber) public view returns (address) {
        return beneficiary[_raffleNumber];
    }

    function getWinningTimestamp(uint256 _raffleNumber) public view returns (uint256) {
        return winningTimestamp[_raffleNumber];
    }

    function getStartTimestamp(uint256 _raffleNumber) public view returns (uint256) {
        return startTimestamp[_raffleNumber];
    }

    function getGuesses(uint256 _raffleNumber, uint256 _guess) public view returns (address) {
        return guesses[_raffleNumber][_guess];
    }

    function getIsRaffleOpen(uint256 _raffleNumber) public view returns (bool) {
        return isRaffleOpen[_raffleNumber];
    }

    function getRaffleNumber() public view returns (uint256) {
        return raffleNumber;
    }

    function getTokenAddress() public view returns (address) {
        return i_tokenAddress;
    }
}
