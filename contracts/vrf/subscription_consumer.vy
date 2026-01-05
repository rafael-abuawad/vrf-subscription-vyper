# pragma version ~=0.4.3
# pragma nonreentrancy off
"""
@title Subscription Consumer
@custom:contract-name subscription_consumer
@license MIT
@author Rafael Abuawad <https://x.com/rabuawad_>
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

from .interfaces import IVRFCoordinatorV2Plus

# @dev Stores the maximum number of random words that can be requested
#      in a single VRF request.
MAX_RANDOM_WORDS: constant(uint256) = 16


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


# @dev Stores the total number of randomness requests that have been sent.
request_count: public(uint256)


# @dev Mapping from request index to request ID. This allows tracking
#      the request ID of each randomness request.
request_ids: public(HashMap[uint256, uint256])


# @dev Stores the ID of the most recently sent randomness request.
#      This can be used to track the latest request without needing
#      to store the request ID externally.
latest_request_id: public(uint256)


# @dev The key hash that determines which VRF job to use. Different
#      key hashes correspond to different gas price ceilings, allowing
#      selection of a specific price tier for randomness requests.
key_hash: public(immutable(bytes32))


# @dev The maximum amount of gas that can be used in the fulfillment
#      callback function. This ensures that the callback has sufficient
#      gas to complete its execution.
callback_gas_limit: public(immutable(uint32))

# @dev The number of block confirmations to wait before the VRF
#      coordinator responds to the request. Higher values provide
#      better security but increase the time to receive randomness.
request_confirmations: public(immutable(uint16))


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
    _vrf_coordinator: address,
    _subscription_id: uint256,
    _key_hash: bytes32,
    _callback_gas_limit: uint32,
    _request_confirmations: uint16,
    _num_words: uint32
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
    @param _callback_gas_limit The maximum amount of gas that can be used in the fulfillment
           callback function. This ensures that the callback has sufficient
           gas to complete its execution.
    @param _request_confirmations The number of block confirmations to wait before the VRF
           coordinator responds to the request. Higher values provide
           better security but increase the time to receive randomness.
    @param _num_words The number of random words to request in each VRF request.
           The number of random words must be between 1 and MAX_RANDOM_WORDS.
    @param _key_hash The 32-byte key hash that determines which VRF
           job and gas price tier to use. Different key hashes have
           different gas price ceilings, allowing selection of a
           specific price tier.
    """
    max_random_words: uint32 = convert(MAX_RANDOM_WORDS, uint32)
    assert _num_words > 0 and _num_words <= max_random_words, "subscription consumer: invalid number of random words"

    vrf_coordinator = IVRFCoordinatorV2Plus(_vrf_coordinator)
    subscription_id = _subscription_id
    callback_gas_limit = _callback_gas_limit
    request_confirmations = _request_confirmations
    num_words = _num_words
    key_hash = _key_hash


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
            keyHash=key_hash,
            subId=subscription_id,
            requestConfirmations=request_confirmations,
            callbackGasLimit=callback_gas_limit,
            numWords=num_words,
            extraArgs=self._args_to_bytes(_enable_native_payment),
        )
    )

    # Initialize the request status with empty random words array
    # The random words will be populated when the request is fulfilled
    request_index: uint256 = self.request_count
    self.request_count += 1
    self.request_ids[request_index] = request_id
    self.requests[request_id].exists = True
    self.latest_request_id = request_id

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
    assert request.exists, "subscription consumer: request not found"

    # Update the request
    request.fulfilled = True
    request.randomWords = _random_words
    self.requests[_request_id] = request
    log RequestFulfilled(requestId=_request_id, randomWords=_random_words)

