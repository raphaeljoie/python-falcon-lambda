FROM python:3.8-buster

RUN apt-get update
RUN apt-get install -y virtualenv
RUN apt-get install -y zip

RUN virtualenv -p python3.8 /venv

COPY build.sh /build.sh
RUN chmod +x /build.sh

WORKDIR workdir

CMD ["/build.sh"]
