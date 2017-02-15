FROM python:3-alpine

RUN pip install raven flask blinker datadog

ADD app/server.py /server.py
RUN chmod +x /server.py
WORKDIR /
ENV FLASK_APP=server.py

CMD ["python", "server.py"]