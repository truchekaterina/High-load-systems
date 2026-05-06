FROM python:3.13-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .

# В контейнере слушаем все интерфейсы; с хоста пробрасывайте 127.0.0.1:18080:18080
EXPOSE 18080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "18080"]
