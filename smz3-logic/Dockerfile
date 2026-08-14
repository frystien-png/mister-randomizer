ARG BUILD_FROM=python:3.12-slim
FROM ${BUILD_FROM}

# Archipelago is pinned to EXACTLY the commit the logic is verified against.
# The logic is sensitive to AP changes, and a floating main could change the
# answers under somebody's feet in the middle of a run.
ARG AP_COMMIT=3359cacedd6eb263f6b6e82cef8f689151217a7a

ENV AP_PATH=/opt/ap \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    mkdir -p /opt/ap; \
    curl -fsSL "https://github.com/ArchipelagoMW/Archipelago/archive/${AP_COMMIT}.tar.gz" \
      | tar -xz --strip-components=1 -C /opt/ap; \
    apt-get purge -y --auto-remove curl; \
    rm -rf /var/lib/apt/lists/*

# Trimming: worlds/__init__.py loads ALL worlds on import. Keep only the three
# games the logic touches plus "generic", which AP's own core imports.
# Measured: 80 worlds -> 4, AP code 123 M -> 38 M, import 2.75 s -> 1.42 s.
# Verified that the answers are byte for byte identical to an untrimmed copy.
RUN set -eux; \
    cd /opt/ap/worlds; \
    for d in */; do \
      d="${d%/}"; \
      case " alttp smz3 sm generic " in \
        *" $d "*) ;; \
        *) rm -rf "$d" ;; \
      esac; \
    done; \
    cd /opt/ap; \
    rm -rf WebHostLib docs .github .git test/benchmark test/cpp; \
    find /opt/ap -name '__pycache__' -type d -prune -exec rm -rf {} +

# A minimal dependency list, arrived at by importing into an empty venv and
# installing what was missing until it went through: 34 M instead of 178 M.
# No Kivy, no Cython - those are GUI and build dependencies the logic never
# touches.
#   setuptools<81  : 81 removed pkg_resources, which Archipelago imports
#   pathspec       : is NOT in AP's requirements.txt but is needed by Utils.py
RUN pip install --no-cache-dir --root-user-action=ignore \
      PyYAML \
      jellyfish \
      jinja2 \
      schema \
      bsdiff4 \
      platformdirs \
      certifi \
      orjson \
      typing_extensions \
      websockets \
      colorama \
      pathspec \
      "setuptools<81"

COPY logic/ /opt/logic/
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8183
CMD ["/run.sh"]
