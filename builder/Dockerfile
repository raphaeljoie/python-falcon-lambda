FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -y python3.8
RUN apt-get install -y virtualenv
RUN apt-get install -y zip

RUN virtualenv -p python3.8 /venv

COPY build.sh /build.sh
RUN chmod +x /build.sh

WORKDIR workdir

CMD ["/build.sh"]
