

# Inferência de LLM no Amazon SageMaker usando Rust

<div align="justify">
Deploy de uma API de inferência de altíssima performance para Large Language Models (LLMs) utilizando Rust, Axum, Candle, Docker, Amazon ECR e Amazon SageMaker. Este projeto demonstra a construção de uma infraestrutura de MLOps completa para servir modelos GGUF em produção, desde a criação da imagem Docker até a disponibilização de um endpoint escalável e robusto na AWS.
</div>

---

## 1. Objetivos

<div align="justify">
Este projeto foi desenvolvido para explorar a implantação de modelos de linguagem de grande porte utilizando uma stack de computação de alta performance baseada em Rust. Os principais objetivos são:
</div>

* **Construir uma API REST** resiliente e de baixa latência para inferência de LLMs.
* **Utilizar o runtime Candle** (Hugging Face) para execução eficiente e segura dos modelos.
* **Automatizar o processo de deploy** utilizando Docker, Amazon ECR e Amazon SageMaker.
* **Demonstrar uma pipeline completa de MLOps** voltada para modelos generativos (LLM Serving).
* **Criar um projeto de portfólio de destaque** com foco em *Machine Learning Engineering* e *Cloud Computing*.

---

## 2. Arquitetura da Solução

```text
Cliente
   │
   ▼
SageMaker Endpoint
   │
   ▼
Container Docker (Amazon ECR)
   │
   ▼
Rust + Axum (Rotas: /ping e /invocations)
   │
   ▼
Candle Runtime (Hugging Face)
   │
   ▼
Llama 3 (Formato GGUF local)
```

---

## 3. Tecnologias Utilizadas

| Tecnologia | Finalidade |
| :--- | :--- |
| **Rust** | Linguagem core para o backend de inferência de alta performance |
| **Axum** | Framework web baseado em `tokio` para construção da API HTTP |
| **Candle** | Runtime de Machine Learning minimalista em Rust pela Hugging Face |
| **Docker** | Containerização do ambiente de execução e isolamento de dependências |
| **Amazon ECR** | Registro privado gerenciado para armazenamento da imagem Docker |
| **Amazon SageMaker** | Hospedagem, gerenciamento e auto-scaling do endpoint de inferência |
| **AWS CLI & Makefile** | Automação de comandos, build e deploy da infraestrutura |
| **GGUF** | Formato de arquivo otimizado para inferência local quantizada de LLMs |

---

## 4. Estrutura do Projeto

```text
sagemaker-rust-llm/
├── Cargo.toml
├── Makefile
├── Dockerfile
├── model/
│   └── Meta-Llama-3-8B-Instruct.Q4_K_M.gguf
└── src/
    └── main.rs
```

---

## 5. Fluxo Completo de MLOps

```text
 Peso GGUF Local 
       │
       ▼
  Docker Build ────► Compilação Binária + Injeção do Modelo
       │
       ▼
   Amazon ECR  ────► Upload da Imagem Otimizada
       │
       ▼
SageMaker Model ───► Instanciação do Artefato no SageMaker
       │
       ▼
 Endpoint Config ──► Definição de Recursos (Instância, Tráfego)
       │
       ▼
Sagemaker Endpoint ► Ativação e Disponibilização do Serviço
       │
       ▼
Inference Requests ► Consumo via API por Clientes Externos
```

---

## 6. Rust no SageMaker: Passo a Passo (Guia de Execução)

<div align="justify">
Abaixo encontra-se o guia operacional sem simplificações para reproduzir integralmente o ambiente de produção.
</div>

### Passo 1: Como obter as Credenciais AWS (IAM)

<div align="justify">
1. Acesse o <b>Console Web da AWS</b>.<br>
2. Na barra de pesquisa superior, procure por <b>IAM</b> e clique no serviço.<br>
3. No menu lateral esquerdo, clique em <b>Users</b> (Usuários) e selecione o seu usuário.<br>
4. Abra a aba <b>Security credentials</b> (Credenciais de segurança).<br>
5. Role a página até a seção <b>Access keys</b> (Chaves de acesso) e clique em <b>Create access key</b>.<br>
6. Selecione a opção <b>Command Line Interface (CLI)</b>, marque a caixa de confirmação e clique em <b>Next</b>.<br>
7. Opcionalmente adicione uma tag de descrição e clique em <b>Create access key</b>.<br>
8. Copie o <b>Access Key ID</b> e a <b>Secret Access Key</b> (clique em <i>Show</i>).<br>
9. <b>Importante:</b> Clique em <b>Download .csv file</b> para armazenar suas credenciais em um local seguro.
</div>

### Passo 2: Organização dos Arquivos no Seu Diretório Local

<div align="justify">
Certifique-se de colocar os pesos do modelo baixado dentro do diretório correspondente antes de iniciar o build do container:
</div>

```bash
# Certifique-se de que o arquivo está no local correto:
sagemaker-rust-llm/model/Meta-Llama-3-8B-Instruct.Q4_K_M.gguf
```

### Passo 3: Autenticação Inicial (AWS CLI)

<div align="justify">
No seu terminal local, execute o comando abaixo para configurar o seu ambiente:
</div>

```bash
aws configure
```

<div align="justify">
Preencha os campos solicitados conforme os dados obtidos no Passo 1:
</div>

* **AWS Access Key ID:** `SUA_ACCESS_KEY`
* **AWS Secret Access Key:** `SUA_SECRET_KEY`
* **Default region name:** `us-east-1`
* **Default output format:** `json`

### Passo 4: Geração da Imagem Docker Local

<div align="justify">
Para que o SageMaker funcione corretamente, os pesos do modelo devem ser organizados internamente dentro do container no caminho esperado pelo ciclo de vida da AWS (<code>/opt/ml/model</code>). Isso é garantido pelas seguintes instruções no seu <code>Dockerfile</code>:
</div>

```dockerfile
RUN mkdir -p /opt/ml/model
COPY model/ /opt/ml/model/
```

<div align="justify">
Para buildar a imagem localmente, execute:
</div>

```bash
make build
```

### Passo 5: Envio da Imagem para o Amazon ECR

<div align="justify">
Crie o repositório no Amazon ECR e realize o upload da imagem taggeada executando:
</div>

```bash
make ecr-create
make push
```

### Passo 6: Configuração de Permissões Críticas no IAM

<div align="justify">
Para que o deploy ocorra sem falhas de autenticação, garanta que seu usuário ou a role de execução possuam as três políticas abaixo associadas no console do IAM (Aba <i>Permissions</i> -> <i>Add permissions</i> -> <i>Attach policies directly</i>):
</div>

1. **`AmazonEC2ContainerRegistryFullAccess`**: Permite gerenciar as imagens no repositório ECR.
2. **`AmazonSageMakerFullAccess`**: Permite gerenciar os modelos, configurações e endpoints do SageMaker.
3. **Política Inline `PassRole`**: Permite ao seu usuário passar a role de execução para o SageMaker. Para criá-la, clique em *Create inline policy*, mude para a aba **JSON**, apague o conteúdo e cole:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowPassRoleToSageMaker",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::634510061385:role/SageMakerExecutionRole"
        }
    ]
}
```

<div align="justify">
Nomeie a política como <code>PassRoleToSageMakerPolicy</code> e conclua a criação.
</div>

### Passo 7: Deploy da Infraestrutura no Amazon SageMaker

<div align="justify">
Com as permissões configuradas e a imagem no ECR, inicialize o provisionamento na AWS:
</div>

```bash
make deploy
```

<div align="justify">
Esse comando criará automaticamente na AWS o <i>SageMaker Model</i>, a <i>Endpoint Configuration</i> e o <i>Endpoint</i> ativo de inferência.
</div>

### Passo 8: Monitoramento do Endpoint

<div align="justify">
O processo de inicialização da instância leva alguns minutos. Monitore o progresso com o comando:
</div>

```bash
watch -n 2 "aws sagemaker describe-endpoint --endpoint-name rust-llm-endpoint --query EndpointStatus"
```

<div align="justify">
Aguarde até que o status mude de <code>Creating</code> para:
</div>

```text
"InService"
```

### Passo 9: Teste de Inferência

<div align="justify">
Crie um arquivo local chamado <code>payload.json</code> com a sua pergunta:
</div>

```json
{
  "inputs": "Qual é a capital da Itália?"
}
```

<div align="justify">
Efetue a requisição diretamente ao endpoint ativo no SageMaker utilizando o comando:
</div>

```bash
aws sagemaker-runtime invoke-endpoint \
    --endpoint-name rust-llm-endpoint \
    --body file://payload.json \
    --content-type application/json \
    output.json
```

<div align="justify">
Para visualizar a resposta gerada pelo modelo Llama 3 via Rust, execute:
</div>

```bash
cat output.json
```

---

## 7. Principais Blocos de Código e Configurações

### Gerenciamento de Dependências (`Cargo.toml`)

<div align="justify">
Ao configurar os recursos do ecossistema Hugging Face em Rust, garanta que não existam chaves duplicadas para o pacote <code>tokenizers</code>. Se utilizar a feature de requisições HTTP do tokenizer, declare-a de forma consolidada para evitar o erro 101 de chave duplicada no Cargo build:
</div>

```toml
[dependencies]
axum = "0.7"
tokio = { version = "1.0", features = ["full"] }
candle-core = { version = "0.6.0" }
candle-transformers = { version = "0.6.0" }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokenizers = { version = "0.19", features = ["http"] }
```

### Carregamento do Modelo (`src/main.rs`)

```rust
let model = Llama::load(
    "/opt/ml/model/Meta-Llama-3-8B-Instruct.Q4_K_M.gguf",
    device
)?;
```

<div align="justify">
O binário em Rust faz o mapeamento direto no ponto de montagem do container do SageMaker, criando um canal de comunicação de baixa latência e eliminando overheads desnecessários de I/O em tempo de execução.
</div>

### Inicialização da API e Requisitos do SageMaker

<div align="justify">
Para que um container customizado seja considerado saudável pelo Amazon SageMaker, ele precisa responder obrigatoriamente a duas rotas: <code>/ping</code> (para o Health Check da instância) e <code>/invocations</code> (para o processamento das inferências).
</div>

```rust
let app = Router::new()
    .route("/ping", get(ping_handler))
    .route("/invocations", post(inference_handler));
```

<div align="justify">
A rota <code>/ping</code> deve retornar o Status HTTP <code>200 OK</code> imediatamente para indicar que o container está operacional e pronto para receber requisições de produção.
</div>

### Processamento da Inferência

```rust
let output = model.generate(
    prompt,
    256
)?;
```

<div align="justify">
Executa a tokenização, o forward pass na estrutura do Candle e a geração de até 256 tokens de resposta de forma otimizada.
</div>

### Retorno da Resposta

```rust
Json(json!({
    "generated_text": output
}))
```

<div align="justify">
Padronização do payload de saída no formato JSON esperado pelo cliente consumidor.
</div>

---

## 8. Resultados Obtidos

| Métrica / Componente | Especificação Tecnológica |
| :--- | :--- |
| **Linguagem Backend** | Rust (Segurança de memória e concorrência sem Garbage Collector) |
| **Framework HTTP** | Axum + Tokio (Arquitetura assíncrona orientada a eventos) |
| **Tensor Runtime** | Candle (Inferência pura nativa em Rust) |
| **Modelo Sediado** | Llama 3 (8B Instruct) |
| **Formato & Otimização** | GGUF Quantizado em 4-bits (`Q4_K_M`) |
| **Hospedagem Produtiva** | Amazon SageMaker Endpoints |
| **Container Registry** | Amazon ECR |

---

## 9. Aprendizados Consolidados

* **Deploy Prático de Modelos Generativos:** Entendimento do ciclo de vida completo de LLMs em produção.
* **LLM Serving de Alta Performance:** Substituição de runtimes tradicionais em Python por binários compilados altamente eficientes em Rust.
* **Containerização Avançada:** Criação de imagens Docker otimizadas contendo o runtime e os artefatos estáticos necessários.
* **Engenharia de Cloud (AWS):** Domínio em arquitetura IAM (Políticas, PassRole), repositórios ECR e gerenciamento de capacidade computacional no SageMaker.

---

## 10. Trabalhos Futuros

* [ ] **Streaming de Tokens:** Implementação de Server-Sent Events (SSE) na API Axum para respostas em tempo real.
* [ ] **Dynamic Batch Inference:** Agrupamento de requisições concorrentes para otimizar a vazão da CPU/GPU.
* [ ] **Auto Scaling Baseado em Demanda:** Configuração de alarmes do CloudWatch para escalabilidade automática de instâncias.
* [ ] **Suporte Nativo à GPU:** Integração com CUDA do Candle para aceleração via hardware nos endpoints da AWS.
* [ ] **KV Cache Persistente:** Otimização do contexto para múltiplos turnos de conversa.

---

## 11. Conclusão

<div align="justify">
Este projeto valida que o ecossistema Rust está maduro e perfeitamente apto para assumir componentes críticos na camada de inferência de Inteligência Artificial. A stack combinando <b>Axum + Candle + SageMaker</b> elimina gargalos tradicionais de concorrência e gerenciamento de memória, reduzindo custos de infraestrutura em nuvem e garantindo latências previsíveis e extremamente baixas para aplicações corporativas.
</div>

```
