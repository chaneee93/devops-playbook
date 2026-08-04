# Python Dockerfile 템플릿
# TODO: requirements.txt 기반 + venv 패턴 추가
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["python", "main.py"]
