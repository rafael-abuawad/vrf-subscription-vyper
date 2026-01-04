from time import sleep
from ape import project, accounts

SUBSCRIPTION_CONSUMER = "0xD107d0E2E5D8f004541cC470Ba5819D24D4788bF"

def main():
    deployer = accounts.load("brave")
    subscription_consumer = project.SubscriptionConsumer.at(SUBSCRIPTION_CONSUMER)

    subscription_consumer.request_random_words(False, sender=deployer)
    request_id = subscription_consumer.last_request_id()
    print(f"Request ID: {request_id}")

    for i in range(5):
        print(f"\t Waiting for {5-i} seconds...")
        sleep(1)

    request = subscription_consumer.requests(request_id)
    print(f"Request status: {request.fulfilled}")
    print(f"Request random words: {request.randomWords}")
    print(f"Request exists: {request.exists}")


