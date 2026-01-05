from ape import project, accounts

# Arbitrum VRF Coordinator
VRF_COORDINATOR = "0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e"
SUBSCRIPTION_ID = 58818501990419443489941997912023711743563562939934605039143263664528524368575
KEY_HASH = "0x9e9e46732b32662b9adc6f3abdf6c5e926a666d174a4d6b8e39c4cca76a38897"
CALLBACK_GAS_LIMIT = 100_000
REQUEST_CONFIRMATIONS = 3
NUM_WORDS = 1

def main():
    deployer = accounts.load("brave")
    print(f"{deployer.address} balance: {deployer.balance/(1e18)} ETH")

    subscription_consumer = project.subscription_consumer_mock.deploy(
        VRF_COORDINATOR,
        SUBSCRIPTION_ID,
        KEY_HASH,
        CALLBACK_GAS_LIMIT,
        REQUEST_CONFIRMATIONS,
        NUM_WORDS,
        sender=deployer,
    )
    return subscription_consumer
