FROM python:3.13.6-slim AS builder

WORKDIR /weather_app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

#------------------------

FROM python:3.13.6-slim

WORKDIR /weather_app

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl gnupg unzip libxi6 libnss3 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libxss1 libpango-1.0-0 libcairo2 \
    && curl -sSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Copy installed python packages from the builder stage
COPY --from=builder /install /usr/local

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]