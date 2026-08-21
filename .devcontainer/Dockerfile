FROM ubuntu:22.04

# Install Java, X11, simulator deps, Python (for Halo emulator), curl/wget for SDK download
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk \
    libatk1.0-0 libcairo2 libexpat1 libfontconfig1 libfreetype6 \
    libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libjavascriptcoregtk-4.0-18 \
    libjpeg-turbo8 libpango-1.0-0 libpangocairo-1.0-0 libpangoft2-1.0-0 \
    libpng16-16 libsecret-1-0 libsm6 libsoup2.4-1 libwebkit2gtk-4.0-37 \
    libx11-6 libxext6 libxxf86vm1 libusb-1.0-0 libcurl4 \
    xvfb make jq git sudo coreutils \
    python3 python3-pip python3-venv \
    curl wget unzip \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} ciq && useradd -m -u ${UID} -g ${GID} -s /bin/bash ciq

# Download and install Connect IQ SDK 9.2.0 (latest as of 2026-06)
ARG CIQ_SDK_VERSION=9.2.0
ARG CIQ_SDK_DATE=2026-06-09-92a1605b2
RUN mkdir -p /home/ciq/.Garmin/ConnectIQ/Sdks \
    && wget -q "https://developer.garmin.com/downloads/connect-iq/sdks/connectiq-sdk-lin-${CIQ_SDK_VERSION}-${CIQ_SDK_DATE}.zip" -O /tmp/ciq-sdk.zip \
    && unzip -q /tmp/ciq-sdk.zip -d /home/ciq/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-${CIQ_SDK_VERSION}-${CIQ_SDK_DATE} \
    && rm /tmp/ciq-sdk.zip \
    && ln -s /home/ciq/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-${CIQ_SDK_VERSION}-${CIQ_SDK_DATE} /home/ciq/.Garmin/ConnectIQ/Sdks/current \
    && echo "/home/ciq/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-${CIQ_SDK_VERSION}-${CIQ_SDK_DATE}" > /home/ciq/.Garmin/ConnectIQ/current-sdk.cfg \
    && chown -R ciq:ciq /home/ciq/.Garmin

# Install connect-iq-sdk-manager-cli (for device profile downloads)
RUN wget -q "https://github.com/lindell/connect-iq-sdk-manager-cli/releases/download/v0.8.4/connect-iq-sdk-manager-cli_0.8.4_Linux_x86_64.tar.gz" -O /tmp/sdk-manager.tar.gz \
    && tar xzf /tmp/sdk-manager.tar.gz -C /usr/local/bin/ connect-iq-sdk-manager \
    && rm /tmp/sdk-manager.tar.gz

ENV PATH=/home/ciq/.Garmin/ConnectIQ/Sdks/current/bin:/home/ciq/.local/bin:${PATH}
ENV DISPLAY=:0
ENV NO_AT_BRIDGE=1

USER ciq
WORKDIR /home/ciq/src

# Install Halo emulator (from source, not on PyPI)
RUN git clone https://github.com/brilliantlabsAR/brilliant_sdk.git /tmp/brilliant_sdk \
    && cd /tmp/brilliant_sdk/python \
    && pip3 install --user packages/halo_emulator \
    && rm -rf /tmp/brilliant_sdk
