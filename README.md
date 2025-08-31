# Fifty-Fifty Raffle Smart Contract

A decentralized raffle system where participants guess timestamps for real-world events. The closest guess wins 50% of the prize pool, while the other 50% goes to a designated beneficiary.

## Overview

The Fifty-Fifty Raffle is a smart contract that enables timestamp-based prediction games on the blockchain. Participants submit their guesses for when a specific event will occur, and the person with the closest guess (without going over) wins half the prize pool. The remaining half goes to a beneficiary, making it perfect for fundraising events or charitable causes.

## Use Cases

### Primary Use Case: Baby Shower Mini-App

The initial implementation is designed for a "Baby Shower" mini-app where:

- **Beneficiary**: Expecting parents
- **Event**: Baby's birth time
- **Participants**: Friends and family guess when the baby will be born
- **Prize Distribution**: 50% to the closest guess, 50% to the parents

### Other Potential Use Cases

- **Weather Events**: Guess when it will rain/snow
- **Sports Events**: Predict game start times or event durations
- **Product Launches**: Guess launch times
- **Charitable Fundraising**: Any event-based fundraising with a beneficiary

## How It Works

### 1. Raffle Creation

- A beneficiary creates a raffle with an entry fee (minimum 1 USDC)
- The raffle starts immediately upon creation
- Participants can begin submitting timestamp guesses

### 2. Entry Process

- Participants pay an entry fee in USDC
- Each guess is a Unix timestamp (rounded down to the nearest minute)
- No duplicate guesses are allowed
- Guesses must be after the raffle start time

### 3. Raffle Closure

- The beneficiary or contract owner can close the raffle
- Once closed, the winning timestamp is set (must be in the past)
- The raffle automatically closes when the winning timestamp is set

### 4. Winner Determination

- The system finds the closest guess that doesn't exceed the actual event time
- If no exact match, it searches backward in 60-second intervals
- The first valid guess found wins

### 5. Prize Distribution

- **50%** goes to the winner
- **50%** goes to the beneficiary
- **Protocol fee** (0.5% by default) is deducted from the total pool

## Smart Contract Features

### Core Functions

- `createRaffle(address beneficiary, uint256 entryFee)`: Create a new raffle
- `enterRaffleWithGuess(uint256 guess, uint256 raffleNumber)`: Submit a timestamp guess
- `closeRaffle(uint256 raffleNumber)`: Close the raffle to new entries
- `setWinningTimestamp(uint256 raffleNumber, uint256 winningTimestamp)`: Set the actual event time
- `distributePrize(uint256 raffleNumber)`: Distribute prizes to winner and beneficiary

### Safety Features

- **Ownable**: Only the contract owner can modify protocol fees
- **Authorization**: Only beneficiaries or owners can close raffles and set winning timestamps
- **Duplicate Prevention**: No two participants can submit the same timestamp
- **Gas Optimization**: Efficient winner search algorithm
- **Emergency Functions**: Manual raffle closure for edge cases

### Technical Specifications

- **Token**: USDC (6 decimals)
- **Protocol Fee**: 0.5% (configurable)
- **Minimum Entry Fee**: 1 USDC
- **Timestamp Precision**: Rounded to nearest minute
- **Network Support**: Base, Base Sepolia, and local development

## Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Node.js and npm (for testing)

### Installation

```bash
git clone <repository-url>
cd fifty_fifty_raffle
forge install
```

### Compilation

```bash
forge build
```

### Testing

```bash
forge test
```

### Deployment

#### Local Development

```bash
# Start local node
anvil

# Deploy in new terminal
forge script script/DeployRaffle.s.sol --rpc-url http://localhost:8545 --broadcast
```

#### Base Network

```bash
# Set your private key
export PRIVATE_KEY=your_private_key_here

# Deploy to Base Sepolia (testnet)
forge script script/DeployRaffle.s.sol --rpc-url https://sepolia.base.org --broadcast --verify

# Deploy to Base (mainnet)
forge script script/DeployRaffle.s.sol --rpc-url https://mainnet.base.org --broadcast --verify
```

## Usage Examples

### Creating a Baby Shower Raffle

```solidity
// Create a raffle for expecting parents
// Entry fee: 5 USDC
raffle.createRaffle(parentsAddress, 5e6);
```

### Submitting a Guess

```solidity
// Guess the baby will be born on December 25, 2024 at 2:30 PM UTC
uint256 guessTime = 1735222200; // Unix timestamp
raffle.enterRaffleWithGuess(guessTime, 1); // raffle #1
```

### Setting the Actual Birth Time

```solidity
// Baby was actually born on December 25, 2024 at 3:15 PM UTC
uint256 actualTime = 1735226100;
raffle.setWinningTimestamp(1, actualTime);
```

### Distributing Prizes

```solidity
// Automatically finds winner and distributes prizes
raffle.distributePrize(1);
```

## Contract Architecture

### Key Components

- **FiftyFiftyRaffle.sol**: Main contract with all raffle logic
- **DeployRaffle.s.sol**: Deployment script with network configuration
- **HelperConfig.s.sol**: Network-specific configuration management
- **RaffleTests.t.sol**: Comprehensive test suite

### State Management

- Multiple raffles can run simultaneously
- Each raffle has its own state (prize pool, entries, winner, etc.)
- Raffle numbers increment sequentially
- All timestamps are stored as Unix timestamps

### Security Considerations

- Reentrancy protection through standard patterns
- Access control for sensitive functions
- Input validation for all parameters
- Emergency functions for edge cases
- Gas limit considerations for winner search

## Gas Optimization

The contract includes several gas optimization features:

- Efficient winner search algorithm
- Minimal storage operations
- Optimized event emissions
- Batch operations where possible

## Testing

The test suite covers:

- Contract deployment and initialization
- Raffle creation and entry
- Winner determination logic
- Prize distribution
- Edge cases and error conditions
- Gas optimization scenarios

Run tests with:

```bash
forge test
forge test --gas-report
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Note**: This contract is designed for educational and experimental purposes. Always test thoroughly on testnets before using on mainnet, and consider having the contract audited for production use.
