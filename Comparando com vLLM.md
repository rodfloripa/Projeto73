# Servindo Modelos GGUF no SageMaker com Rust, Axum e Candle

## 1. Visão Geral

Utilizar **Rust + Axum + Candle** para servir modelos **GGUF** dentro do Amazon SageMaker é uma abordagem totalmente válida, especialmente quando o objetivo é reduzir custos, minimizar latência ou executar inferência em ambientes CPU-only.

Embora a AWS normalmente recomende soluções como **LMI**, **vLLM** ou **Text Generation Inference (TGI)**, uma stack baseada em Rust oferece vantagens significativas em simplicidade operacional, controle de recursos e eficiência de execução.

A principal diferença é que essa arquitetura não foi projetada para maximizar throughput em larga escala, mas sim para entregar inferência eficiente com baixo consumo de recursos.

[Veja aqui vantagens e desvantagens do projeto e comparação com vLLM](https://github.com/rodfloripa/Projeto73/blob/main/Comparando%20com%20vLLM.md)

---

# 2. O Que Você Ganha com Rust + Axum + Candle

## Vantagens

- Binário pequeno e fácil de distribuir.
- Startup extremamente rápido.
- Controle total sobre memória.
- Sem overhead do ecossistema Python.
- Carregamento direto de modelos GGUF.
- Excelente para CPU-only.

## Desvantagens

- Sem PagedAttention.
- Sem Continuous Batching.
- Sem Tensor Parallel.
- Throughput inferior ao vLLM.
- Ecossistema menor.

---

# 3. GGUF no SageMaker

## Benefícios

Modelos quantizados permitem reduzir drasticamente os requisitos de hardware.

Exemplo:

- Llama 7B Q4 ≈ 4 GB RAM.
- Possibilidade de uso em instâncias pequenas.
- Custo operacional extremamente baixo.

## Limitações

- Pequena perda de qualidade.
- Inferência mais lenta.
- CPU pode ser 10x–20x mais lenta que GPU.

---

# 4. Quando Essa Arquitetura é a Melhor Escolha

| Cenário | Melhor Opção |
|----------|----------|
| CPU-only e baixo custo | Rust + Candle + GGUF |
| Latência mínima | Rust + Candle |
| Edge Computing | Rust + Candle |
| Alto throughput | vLLM + GPU |
| Modelos 70B+ | TensorRT-LLM |

## CPU-Only

Se o objetivo é gastar menos de US$50/mês, dificilmente existe solução melhor.

## Latência

Para batch=1:

- Sem Python.
- Sem gRPC.
- Menor overhead.

## Edge

Roda facilmente em:

- Raspberry Pi
- Mini PCs
- Ambientes embarcados

## Escalabilidade

Para centenas de requisições simultâneas:

- vLLM
- TGI
- TensorRT-LLM

continuam superiores.

---

# 5. Pontos de Atenção no SageMaker

## 5.1 Health Check

O SageMaker espera:

```http
GET /ping
```

Retorno:

```http
200 OK
```

em poucos segundos.

### Solução

Carregar o modelo antes de iniciar o servidor.

```rust
let model = load_model()?;

let app = Router::new()
    .route("/ping", get(ping))
    .route("/invocations", post(invoke));
```

---

## 5.2 Multi Model Endpoint

MMEs foram projetados principalmente para o ecossistema Python.

### Recomendação

```text
1 modelo = 1 endpoint
```

---

## 5.3 Auto Scaling

Evite confiar apenas em:

```text
CPUUtilization
```

Prefira:

```text
SageMakerVariantInvocationsPerInstance
```

---

## 5.4 Streaming

Candle não fornece streaming pronto.

Você precisará implementar:

- SSE
- NDJSON
- Chunked Responses

---

## 5.5 GPU

Se a meta for GPU:

- vLLM normalmente entrega mais tokens/s.
- TensorRT-LLM escala melhor.
- PagedAttention faz diferença significativa.

---

# 6. Comparação Direta

| Característica | Rust + Candle | vLLM |
|---------------|---------------|------|
| CPU-only | Excelente | Fraco |
| GPU | Bom | Excelente |
| Throughput | Médio | Excelente |
| Latência Batch=1 | Excelente | Boa |
| Deploy Simples | Excelente | Médio |
| Escalabilidade | Média | Excelente |
| Consumo de RAM | Baixo | Médio |
| Custo | Muito baixo | Alto |

---

# 7. Avaliação Final

## Aprendizado de MLOps

Nota: **10/10**

Você controla toda a cadeia:

```text
Modelo
 ↓
Docker
 ↓
ECR
 ↓
SageMaker
 ↓
Endpoint
```

## Baixo Custo

Nota: **10/10**

Provavelmente a melhor combinação para CPU-only.

## Escala Massiva

Nota: **6/10**

vLLM e TensorRT-LLM continuam liderando.

---

# 8. Conclusão

Rust + Axum + Candle + GGUF não é a arquitetura mais comum dentro da AWS.

Porém é uma excelente escolha para:

- baixo custo;
- inferência CPU-only;
- baixa latência;
- edge computing;
- aprendizado de MLOps;
- controle total da stack.

A arquitetura padrão da AWS prioriza escalabilidade.

A arquitetura Rust + Candle + GGUF prioriza eficiência, simplicidade e custo.
