import time


APPLICATION_START_TIME = time.time()

REQUEST_COUNT = 0


def increment_requests():

    global REQUEST_COUNT

    REQUEST_COUNT += 1


def get_request_count():

    return REQUEST_COUNT


def get_uptime():

    return round(
        time.time() - APPLICATION_START_TIME,
        2
    )