# pragma version ~=0.4.3
# pragma nonreentrancy off
"""
@title Subscription Consumer
@custom:contract-name SubscriptionConsumer
@license MIT
"""

from interfaces import IVRFCoordinatorV2Plus

MAX_RANDOM_WORDS: constant(uint256) = 2

# bytes4 public constant EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"));
EXTRA_ARGS_V1_TAG: constant(bytes4) = 0x92fd1338


event RequestSent:
    requestId: uint256
    numWords: uint32


event RequesetFulfilled:
    requestId: uint256
    randomWords: uint256[MAX_RANDOM_WORDS]


struct RequestStatus:
    fulfilled: bool
    exists: bool
    randomWords: uint256[MAX_RANDOM_WORDS]


requests: public(HashMap[uint256, RequestStatus])
last_request_id: public(uint256)

key_hash: public(bytes32)
callback_gas_limit: public(constant(uint32)) = 100_000  # 100,000
request_confirmations: public(constant(uint16)) = 3
num_words: public(constant(uint32)) = 2

vrf_coordinator: public(immutable(IVRFCoordinatorV2Plus))
vrf_coordinator_address: public(immutable(address))
subscription_id: public(immutable(uint256))


@deploy
def __init__(
    _vrf_coordinator: address, _subscription_id: uint256, _key_hash: bytes32
):
    vrf_coordinator = IVRFCoordinatorV2Plus(_vrf_coordinator)
    vrf_coordinator_address = _vrf_coordinator
    subscription_id = _subscription_id
    self.key_hash = _key_hash


@internal
def _args_to_bytes(_enable_native_payment: bool) -> Bytes[36]:
    return abi_encode(_enable_native_payment, method_id=EXTRA_ARGS_V1_TAG)


@external
def request_random_words(_enable_native_payment: bool) -> uint256:
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

    random_words: uint256[MAX_RANDOM_WORDS] = empty(uint256[MAX_RANDOM_WORDS])
    self.requests[request_id] = RequestStatus(
        fulfilled=False,
        exists=True,
        randomWords=random_words,
    )

    self.last_request_id = request_id
    log RequestSent(requestId=request_id, numWords=num_words)
    return request_id


@internal
def _fullill_random_words(
    _request_id: uint256, _random_words: uint256[MAX_RANDOM_WORDS]
):
    assert self.requests[_request_id].exists, "request not found"
    self.requests[_request_id].fulfilled = True
    self.requests[_request_id].randomWords = _random_words
    log RequesetFulfilled(requestId=_request_id, randomWords=_random_words)


@external
def fulfillRandomWords(
    _request_id: uint256, _random_words: uint256[MAX_RANDOM_WORDS]
):
    self._fullill_random_words(_request_id, _random_words)


@external
def rawFulfillRandomWords(
    _request_id: uint256, _random_words: uint256[MAX_RANDOM_WORDS]
):
    assert msg.sender == vrf_coordinator.address, "Only VRF coordinator can fulfill"
    self._fullill_random_words(_request_id, _random_words)


@external
def setKeyHash(_key_hash: bytes32):
    self.key_hash = _key_hash
