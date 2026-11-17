FROM tt-sky130-env:latest

ENV PDK=gf180mcuD \
    PDK_ROOT=/ttsetup/pdk \
    LIBRELANE_TAG=3.0.14 \
    PATH=/ttsetup/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# The base image's Verilator 5.020 is too old for cocotb 2.1.
RUN apt-get update \
    && apt-get install -y --no-install-recommends autoconf flex bison libfl-dev help2man zlib1g-dev \
    && git clone --depth 1 --branch v5.046 https://github.com/verilator/verilator.git /tmp/verilator \
    && cd /tmp/verilator \
    && autoconf \
    && ./configure --prefix=/usr/local \
    && make -j4 \
    && make install \
    && rm -rf /tmp/verilator /var/lib/apt/lists/*

COPY test/requirements.txt /ttsetup/test_requirements.txt
RUN pip install --no-cache-dir -r /ttsetup/test_requirements.txt librelane==${LIBRELANE_TAG} \
    && pip check

CMD ["/bin/bash"]
