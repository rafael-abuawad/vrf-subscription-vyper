# pragma version ~=0.4.3
# pragma nonreentrancy off
"""
@title Subscription Consumer
@custom:contract-name SubscriptionConsumer
@license MIT
@notice This contract implements a consumer for Chainlink VRF (Verifiable Random Function)
        using the subscription model. It allows requesting random words from the VRF
        coordinator and handling the fulfillment callback. The contract supports
        both LINK token payment and native token payment modes through the extraArgs
        parameter. Key features include:
        - Request random words from VRF coordinator
        - Track request status and fulfillment
        - Support for native payment mode via extraArgs
        - Configurable key hash for different gas price tiers
        - Callback gas limit and confirmation settings
"""

from interfaces import IVRFCoordinatorV2Plus

# @dev Stores the maximum number of random words that can be requested
#      in a single VRF request.
MAX_RANDOM_WORDS: constant(uint256) = 1


# @dev The method ID tag for VRF ExtraArgsV1 encoding. This tag is used
#      to identify the version of extra arguments being passed to the
#      VRF coordinator. Computed from `bytes4(keccak256("VRF ExtraArgsV1"))`.
EXTRA_ARGS_V1_TAG: constant(bytes4) = 0x92fd1338


# @dev Emitted when a randomness request is sent to the VRF coordinator.
# @param requestId The unique identifier for the randomness request.
# @param numWords The number of random words requested.
event RequestSent:
    requestId: uint256
    numWords: uint32


# @dev Emitted when a randomness request has been fulfilled by the VRF coordinator.
# @param requestId The unique identifier for the fulfilled randomness request.
# @param randomWords The array of random words that were generated.
event RequestFulfilled:
    requestId: uint256
    randomWords: DynArray[uint256, MAX_RANDOM_WORDS]


# @dev Stores the status and results of a randomness request.
# @param fulfilled Indicates whether the request has been fulfilled.
# @param exists Indicates whether the request exists in the mapping.
# @param randomWords The array of random words returned by the VRF coordinator.
struct RequestStatus:
    fulfilled: bool
    exists: bool
    randomWords: DynArray[uint256, MAX_RANDOM_WORDS]


# @dev Mapping from request ID to request status. This allows tracking
#      the state of each randomness request and retrieving the generated
#      random words after fulfillment.
requests: public(HashMap[uint256, RequestStatus])


# @dev Stores the ID of the most recently sent randomness request.
#      This can be used to track the latest request without needing
#      to store the request ID externally.
last_request_id: public(uint256)


# @dev The key hash that determines which VRF job to use. Different
#      key hashes correspond to different gas price ceilings, allowing
#      selection of a specific price tier for randomness requests.
key_hash: public(bytes32)


# @dev The maximum amount of gas that can be used in the fulfillment
#      callback function. This ensures that the callback has sufficient
#      gas to complete its execution.
# @notice The value is set to 100,000 gas units, which should be
#         sufficient for most use cases. Adjust if your fulfillment
#         logic requires more gas.
callback_gas_limit: public(constant(uint32)) = 100_000  # 100,000


# @dev The number of block confirmations to wait before the VRF
#      coordinator responds to the request. Higher values provide
#      better security but increase the time to receive randomness.
# @notice The value is set to 3 confirmations, which is a common
#         balance between security and speed.
request_confirmations: public(constant(uint16)) = 3


# @dev The number of random words to request in each VRF request.
num_words: public(immutable(uint32))


# @dev The address of the VRF coordinator contract. This is set at
#      deployment time and cannot be changed afterward.
vrf_coordinator: public(immutable(IVRFCoordinatorV2Plus))


# @dev The subscription ID for the VRF subscription. This subscription
#      must be funded with LINK tokens (or native tokens if using native
#      payment mode) to cover the cost of randomness requests.
subscription_id: public(immutable(uint256))


@deploy
def __init__(
    _vrf_coordinator: address, _subscription_id: uint256, _key_hash: bytes32
):
    """
    @dev Initializes the VRF subscription consumer contract with the
         required parameters for interacting with the VRF coordinator.
    @notice At initialization time, the contract sets up the immutable
            references to the VRF coordinator and subscription, and
            configures the key hash for randomness requests.
    @param _vrf_coordinator The 20-byte address of the VRF coordinator
           contract that will handle randomness requests.
    @param _subscription_id The 32-byte subscription ID that identifies
           the VRF subscription to use for funding randomness requests.
           This subscription must be created and funded separately.
    @param _key_hash The 32-byte key hash that determines which VRF
           job and gas price tier to use. Different key hashes have
           different gas price ceilings, allowing selection of a
           specific price tier.
    """
    vrf_coordinator = IVRFCoordinatorV2Plus(_vrf_coordinator)
    subscription_id = _subscription_id
    num_words = convert(MAX_RANDOM_WORDS, uint32)
    self.key_hash = _key_hash


@internal
def _args_to_bytes(_enable_native_payment: bool) -> Bytes[36]:
    """
    @dev Encodes the extra arguments for VRF requests into a 36-byte
         format that includes the method ID tag and the native payment
         flag.
    @notice This function creates the extraArgs parameter that tells
            the VRF coordinator whether to use native token payment
            instead of LINK token payment for the request.
    @param _enable_native_payment The Boolean flag that indicates
           whether to use native token payment (True) or LINK token
           payment (False) for the randomness request.
    @return Bytes The 36-byte encoded extra arguments, consisting of
            the 4-byte method ID tag followed by the encoded boolean
            value.
    """
    return abi_encode(_enable_native_payment, method_id=EXTRA_ARGS_V1_TAG)


@external
def request_random_words(_enable_native_payment: bool) -> uint256:
    """
    @dev Requests random words from the VRF coordinator using the
         configured subscription and parameters.
    @notice This function sends a randomness request to the VRF
            coordinator and stores the request status locally. The
            request will be fulfilled asynchronously by the VRF
            coordinator, which will call `fulfillRandomWords`
            with the generated random words. The subscription must
            be funded with sufficient LINK tokens (or native tokens
            if native payment is enabled) to cover the request cost.
            The request will be fulfilled after the specified number
            of block confirmations have passed.
    @param _enable_native_payment The Boolean flag that determines
           the payment method. If True, the request will be paid
           using native tokens from the subscription. If False, the
           request will be paid using LINK tokens from the subscription.
    @return uint256 The unique request ID that identifies this
            randomness request. This ID can be used to track the
            request status and retrieve the random words after
            fulfillment.
    """
    # Use the struct from the interface directly
    request_id: uint256 = extcall vrf_coordinator.requestRandomWords(
        IVRFCoordinatorV2Plus.RandomWordsRequest(
            keyHash=self.key_hash,
            subId=subscription_id,
            requestConfirmations=request_confirmations,
            callbackGasLimit=callback_gas_limit,
            numWords=num_words,
            extraArgs=self._args_to_bytes(_enable_native_payment),
        )
    )

    # Initialize the request status with empty random words array
    # The random words will be populated when the request is fulfilled
    self.requests[request_id].exists = True
    self.last_request_id = request_id
    
    log RequestSent(requestId=request_id, numWords=num_words)
    return request_id


@internal
def _fulfill_random_words(
    _request_id: uint256, _random_words: DynArray[uint256, MAX_RANDOM_WORDS]
):
    """
    @dev Internal function that processes the fulfillment of a
         randomness request by updating the request status and
         storing the generated random words.
    @notice This function is called by `fulfillRandomWords`
            when the VRF coordinator fulfills the request.
            It ensures that the request exists, marks it as fulfilled,
            stores the random words, and emits a fulfillment event.
    @param _request_id The 32-byte unique identifier for the
           randomness request that is being fulfilled.
    @param _random_words The array of random words generated by
           the VRF coordinator. The length of this array must
           match the `num_words` value specified in the original
           request.
    """
    assert msg.sender == vrf_coordinator.address

    request: RequestStatus = self.requests[_request_id]
    assert request.exists, "request not found"

    # Update the request
    request.fulfilled = True
    request.randomWords = _random_words
    self.requests[_request_id] = request
    log RequestFulfilled(requestId=_request_id, randomWords=_random_words)


@external
def fulfillRandomWords(
    _request_id: uint256, _random_words: DynArray[uint256, MAX_RANDOM_WORDS]
):
    """
    @dev Fulfills a randomness request with the provided random words.
         This function is called by the VRF coordinator when a
         randomness request has been fulfilled.
    @notice This function enforces that only the VRF coordinator can
            call it, ensuring that random words can only be set by
            the trusted VRF coordinator contract. The VRF coordinator
            will automatically call this function after the required
            number of block confirmations have passed and the randomness
            has been generated.
    @param _request_id The 32-byte unique identifier for the
           randomness request that is being fulfilled.
    @param _random_words The array of random words generated by
           the VRF coordinator. The length of this array must
           match the `num_words` value specified in the original
           request.
    """
    self._fulfill_random_words(_request_id, _random_words)


@external
def rawFulfillRandomWords(
    _request_id: uint256, _random_words: DynArray[uint256, MAX_RANDOM_WORDS]
):
    """
    @dev Legacy wrapper function for fulfillRandomWords. This function
         is kept for backward compatibility with older VRF versions.
    @notice In VRF v2.5, the coordinator calls fulfillRandomWords directly.
            This function provides the same functionality for compatibility.
            It enforces that only the VRF coordinator can call it.
    @param _request_id The 32-byte unique identifier for the
           randomness request that is being fulfilled.
    @param _random_words The array of random words generated by
           the VRF coordinator. The length of this array must
           match the `num_words` value specified in the original
           request.
    """
    self._fulfill_random_words(_request_id, _random_words)


@external
def setKeyHash(_key_hash: bytes32):
    """
    @dev Updates the key hash used for randomness requests. This
         allows changing the gas price tier for future requests
         without redeploying the contract.
    @notice Different key hashes correspond to different VRF jobs
            with different gas price ceilings. Changing the key
            hash allows selecting a different price tier for
            randomness requests. This can be useful if gas prices
            change significantly or if you want to switch between
            different VRF configurations.
    @param _key_hash The 32-byte key hash that determines which
           VRF job and gas price tier to use for future randomness
           requests. This key hash must correspond to a valid VRF
           job configured in the VRF coordinator.
    """
    self.key_hash = _key_hash
