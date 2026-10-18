# Stage 1 (builder): проверяем скрипт и готовим файлы
FROM ubuntu:22.04 AS builder
WORKDIR /build
COPY script.sh sample_output.txt README.md ./
RUN bash -n script.sh && chmod +x script.sh

# Stage 2 (runtime): финальный образ с Python веб-сервером
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /var/www
COPY --from=builder /build/script.sh /usr/local/bin/script.sh
COPY --from=builder /build/sample_output.txt /build/README.md /var/www/
EXPOSE 8080
CMD ["/bin/bash", "-c", "/usr/local/bin/script.sh & exec python3 -m http.server 8080"]
