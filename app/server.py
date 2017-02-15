import logging
import socket
import sys
import os
from flask import Flask
from raven.contrib.flask import Sentry


def create_app():
	sentry_url = os.getenv('SENTRY_URL').strip()
	sentry = Sentry(dsn=sentry_url)
	print("sentry", sentry_url)
	app = Flask(__name__)
	app.logger.addHandler(logging.StreamHandler(sys.stdout))
	app.logger.setLevel(logging.DEBUG)
	sentry.init_app(app)
	return app

app = create_app()

@app.route('/exception')
def raise_error():
	raise NameError("TEST {0}".format(socket.gethostname()))

@app.route('/')
def hello_world():
	output = "Hello World! host:{0}".format(socket.gethostname())
	app.logger.info(output)
	return output

app.run(host='0.0.0.0', port=8001)