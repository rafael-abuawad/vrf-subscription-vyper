from time import sleep
from ape import project, accounts

SUBSCRIPTION_CONSUMER = "0xdd5726384b4A8fEcA4c87cFB2663a45B48251403"

def main():
    deployer = accounts.load("brave")
    subscription_consumer = project.subscription_consumer_mock.at(SUBSCRIPTION_CONSUMER)

    subscription_consumer.request_random_words(False, sender=deployer)
    request_id = subscription_consumer.latest_request_id()
    print(f"Request ID: {request_id}")

    for i in range(5):
        print(f"\t Waiting for {5-i} seconds...")
        sleep(1)

    request = subscription_consumer.requests(request_id)
    print(f"Request status: {request.fulfilled}")
    print(f"Request random words: {request.randomWords}")
    print(f"Request exists: {request.exists}")


