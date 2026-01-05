from time import sleep
from ape import project, accounts

SUBSCRIPTION_CONSUMER = "0x0f31aDCc9cac028E9a0596E8A3C0E19b3B73bb9A"

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


