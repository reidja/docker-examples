import logging
import socket
import sys
import logging
import socket
import sys
import os
import random
from flask import Flask
from raven.contrib.flask import Sentry
from datadog import api
from datadog import initialize
from datadog import statsd


def create_app():
    app = Flask(__name__)
    app.logger.addHandler(logging.StreamHandler(sys.stdout))
    app.logger.setLevel(logging.DEBUG)
    sentry_url = os.getenv('SENTRY_URL').strip()
    if sentry_url is not None or len(sentry_url) > 0:
        sentry = Sentry(dsn=sentry_url)
        sentry.init_app(app)

    datadog_api_key = os.getenv('DATADOG_API_KEY').strip()
    datadog_app_key = os.getenv('DATADOG_APP_KEY').strip()

    initialize(**{
        "api_key": datadog_api_key,
        "app_key": datadog_app_key,
        "statsd_host": "datadog"
    })

    return app

app = create_app()

@app.route('/exception')
def raise_error():
    statsd.increment('exceptions.hits')
    raise NameError("TEST {0}".format(socket.gethostname()))

@app.route('/')
def hello_world():
    statsd.increment('helloworld.hits')
    statsd.gauge('value', random.randrange(20, 40))

    output = "Hello World! host:{0}".format(socket.gethostname())
    app.logger.info(output)
    return output

api.Event.create(title="Appserver started.", text=socket.gethostname(), tags=['hello','world'])
app.run(host='0.0.0.0', port=8001)