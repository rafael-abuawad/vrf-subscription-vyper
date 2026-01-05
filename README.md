# VRF Subscription Consumer (Vyper)

A Vyper smart contract implementation for consuming Chainlink VRF (Verifiable Random Function) v2.5 using the subscription model. This contract allows requesting verifiable random numbers from Chainlink's VRF coordinator on Arbitrum.

## Features

- **VRF v2.5 Integration**: Uses the latest Chainlink VRF coordinator with subscription model
- **Flexible Payment**: Supports both LINK token and native token payment modes
- **Request Tracking**: Tracks request status and stores random words after fulfillment
- **Configurable Parameters**: Adjustable key hash, callback gas limit, and confirmation settings
- **Event Logging**: Emits events for request submission and fulfillment

## Prerequisites

- Python 3.13+
- [Ape Framework](https://docs.apeworx.io/) installed
- A funded Chainlink VRF subscription

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd vrf-subscription-vyper
```

2. Install dependencies using `uv`:
```bash
uv sync
```

Or using pip:
```bash
uv pip install -r requirements.txt
```

## Configuration

The project uses Ape Framework for configuration. Key configuration files:

- `ape-config.yaml`: Ape Framework configuration with Vyper and Arbitrum plugins
- `pyproject.toml`: Project metadata and dependencies

### Setting Up VRF Subscription

Before deploying, you need:

1. **VRF Coordinator Address**: The Chainlink VRF coordinator contract address
2. **Subscription ID**: A funded VRF subscription ID
3. **Key Hash**: The key hash for your desired gas price tier

Update these values in `scripts/deploy.py` before deployment.

## Usage

### Deployment

Deploy the contract using the deployment script:

```bash
ape run scripts/deploy.py
```

The script will:
- Load your account (configured as "brave" in the example)
- Deploy the `SubscriptionConsumer` contract
- Return the deployed contract address

### Requesting Random Words

Request random words using the test script:

```bash
ape run scripts/rand.py
```

This script will:
- Request random words from the VRF coordinator
- Wait for fulfillment
- Display the request status and random words

### Contract Interaction

#### Request Random Words

```python
from ape import project, accounts

# Connect to deployed contract
subscription_consumer = project.SubscriptionConsumer.at("<CONTRACT_ADDRESS>")
deployer = accounts.load("brave")

# Request random words (False = LINK payment, True = native payment)
subscription_consumer.request_random_words(False, sender=deployer)

# Get the request ID
request_id = subscription_consumer.last_request_id()
```

#### Check Request Status

```python
# Get request status
request = subscription_consumer.requests(request_id)
print(f"Fulfilled: {request.fulfilled}")
print(f"Random Words: {request.randomWords}")
```

#### Update Key Hash

```python
# Update the key hash for different gas price tier
new_key_hash = "0x..."
subscription_consumer.setKeyHash(new_key_hash, sender=deployer)
```

## Contract Details

### Main Functions

- `request_random_words(bool)`: Requests random words from VRF coordinator
  - Parameter: `_enable_native_payment` - Use native token payment if `True`, LINK if `False`
  - Returns: Request ID

- `fulfillRandomWords(uint256, uint256[])`: Called by VRF coordinator to fulfill requests
  - Only callable by the VRF coordinator

- `setKeyHash(bytes32)`: Updates the key hash for future requests

### Configuration Constants

- `callback_gas_limit`: 100,000 gas units
- `request_confirmations`: 3 block confirmations
- `MAX_RANDOM_WORDS`: 1 (configurable in contract)

### Events

- `RequestSent`: Emitted when a randomness request is submitted
- `RequestFulfilled`: Emitted when a request is fulfilled with random words

## Project Structure

```
vrf-subscription-vyper/
├── contracts/
│   ├── SubscriptionConsumer.vy      # Main VRF consumer contract
│   └── interfaces/
│       └── IVRFCoordinatorV2Plus.vyi # VRF coordinator interface
├── scripts/
│   ├── deploy.py                    # Deployment script
│   └── rand.py                      # Random word request script
├── tests/                           # Test files
├── ape-config.yaml                  # Ape Framework configuration
├── pyproject.toml                   # Project configuration
└── requirements.txt                 # Python dependencies
```

## Development

### Compile Contracts

```bash
ape compile
```

### Run Tests

```bash
ape test
```

## License

MIT

## Resources

- [Chainlink VRF Documentation](https://docs.chain.link/vrf/v2-5)
- [Ape Framework Documentation](https://docs.apeworx.io/)
- [Vyper Documentation](https://docs.vyperlang.org/)

