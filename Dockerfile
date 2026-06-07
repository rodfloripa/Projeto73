# --- Estágio de Compilação (Builder) ---
FROM rust:slim AS builder
WORKDIR /usr/src/sagemaker-rust-llm

RUN apt-get update && apt-get install -y \
    libssl-dev \
    pkg-config \
    g++ \
    && rm -rf /var/lib/apt/lists/*

COPY . .
RUN cargo build --release

# --- Estágio de Execução (Runtime) ---
FROM ubuntu:24.04
WORKDIR /app

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copia o binário final compilado
COPY --from=builder /usr/src/sagemaker-rust-llm/target/release/sagemaker-rust-llm /app/server

# NOVO: Copia o tokenizer.json baixado da sua máquina para dentro do container de execução
COPY tokenizer.json /app/tokenizer.json

EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/app/server"]
