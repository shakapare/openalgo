# ------------------------------ Builder Stage ------------------------------ #
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY pyproject.toml .

# Install the base dependencies from the original repository
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the additional requirements and install them
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the openalgo source code into the container
COPY . .

# create isolated virtual-env with uv, then add gunicorn + eventlet
 RUN pip install --no-cache-dir uv && \
    uv venv .venv && \
    uv pip install --upgrade pip && \
    uv sync && \
    uv pip install gunicorn eventlet && \
#    uv pip install pymysql && \
#    uv pip install kiteconnect && \
#    uv pip install upstox-python && \
    rm -rf /root/.cache
# --------------------------------------------------------------------------- #



# ------------------------------ Production Stage --------------------------- #
FROM python:3.13-slim-bookworm AS production

# 0 – set timezone to IST (Asia/Kolkata)
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && \
    ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 1 – user & workdir
RUN useradd --create-home appuser
WORKDIR /app

# 2 – copy the ready-made venv and source with correct ownership
COPY --from=builder --chown=appuser:appuser /app/.venv /app/.venv
COPY --chown=appuser:appuser . .

# 3 – create required directories with proper ownership
RUN mkdir -p /app/logs /app/db && \
    chown -R appuser:appuser /app/logs /app/db

# 4 – entrypoint script and fix line endings
COPY --chown=appuser:appuser start.sh /app/start.sh
RUN sed -i 's/\r$//' /app/start.sh && chmod +x /app/start.sh

# ---- RUNTIME ENVS --------------------------------------------------------- #
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Kolkata
# --------------------------------------------------------------------------- #

USER appuser
EXPOSE 5000
CMD ["/app/start.sh"]
