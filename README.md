
# Inferência de LLM no Sage,aker usando Rust

<div align="justify">

Deploy de uma API de inferência para Large Language Models utilizando Rust, Axum, Candle, Docker, Amazon ECR e Amazon SageMaker.

O projeto demonstra a construção de uma infraestrutura completa para servir modelos GGUF em produção, desde a criação da imagem Docker até a disponibilização de um endpoint escalável na AWS.

</div>

---

# 1. Objetivos

<div align="justify">

Este projeto foi desenvolvido para explorar a implantação de modelos de linguagem utilizando uma stack de alta performance baseada em Rust.

Os principais objetivos foram:

- Construir uma API REST para inferência de LLMs.
- Utilizar o runtime Candle para execução eficiente dos modelos.
- Automatizar o processo de deploy utilizando Docker, ECR e SageMaker.
- Demonstrar uma pipeline completa de MLOps para modelos generativos.
- Criar um projeto de portfólio com foco em Machine Learning Engineering e Cloud Computing.

</div>

---

# 2. Arquitetura da Solução

```text
Cliente
   │
   ▼
SageMaker Endpoint
   │
   ▼
Container Docker
   │
   ▼
Rust + Axum
   │
   ▼
Candle Runtime
   │
   ▼
Llama 3 (GGUF)
```

---

# 3. Tecnologias Utilizadas

| Tecnologia | Finalidade |
|------------|------------|
| Rust | Backend de inferência |
| Axum | API HTTP |
| Candle | Runtime LLM |
| Docker | Containerização |
| Amazon ECR | Registro de imagens |
| Amazon SageMaker | Hospedagem do endpoint |
| AWS CLI | Automação |
| GGUF | Formato do modelo |

---

# 4. Estrutura do Projeto

```text
sagemaker-rust-llm/
├── Cargo.toml
├── Makefile
├── Dockerfile
├── Meta-Llama-3-8B-Instruct.Q4_K_M.gguf
└── src
    └── main.rs
```

---

# 5. Fluxo Completo

```text
GGUF
 │
 ▼
Docker Build
 │
 ▼
Amazon ECR
 │
 ▼
SageMaker Model
 │
 ▼
Endpoint Configuration
 │
 ▼
Endpoint
 │
 ▼
Inference Requests
```

---

# 6. Guia de Execução

<div align="justify">

A partir deste ponto, o conteúdo abaixo corresponde ao guia operacional completo utilizado para realizar o deploy da solução.

Nenhuma etapa foi simplificada, permitindo reproduzir integralmente o ambiente de produção.

</div>

---

# Estrutura e Fluxo do Projeto

Este projeto compila uma API de inferência de altíssima performance escrita em **Rust (Axum + Candle)**, embutindo os pesos do modelo **Llama-3 (GGUF)** dentro de um container Docker. Esse container é enviado ao **Amazon ECR** e gerenciado pelo **Amazon SageMaker** para servir um endpoint de produção escalável.

---

# Guia de Execução Completo (Passo a Passo)

### Passo 1: Como obter as Credenciais AWS (Access Key ID e Secret Access Key)

Se você estiver usando uma conta pessoal ou corporativa (não-estudante), você precisa gerar essas chaves através do IAM:

1. Acesse o Console Web da AWS no seu navegador.
2. Na barra de pesquisa superior, digite IAM (Identity and Access Management) e clique no serviço.
3. No menu lateral esquerdo, clique em Users (Usuários) e selecione o seu usuário (`rodney`).
4. Vá até a aba Security credentials (Credenciais de segurança).
5. Desça a página até a seção Access keys e clique no botão Create access key.
6. Selecione a opção Command Line Interface (CLI), marque a caixa de confirmação de termos no final da página e clique em Next.
7. Se quiser, dê uma descrição (ex: "Chave Terminal Ubuntu") e clique em Create access key.
8. Muito importante: a tela a seguir é a única vez que a AWS exibirá a sua chave secreta.
   - Copie o Access Key ID.
   - Clique em Show e copie a Secret Access Key.
   - Clique em Download .csv file para salvar essas chaves em um local seguro.

---

### Passo 2: Organização dos Arquivos no Seu Diretório Local

Abra o terminal no seu Ubuntu, navegue até a raiz da pasta do seu projeto e garanta que o arquivo de pesos `.gguf` esteja no mesmo nível que o seu Dockerfile:

```text
sagemaker-rust-llm/
├── Cargo.toml
├── Makefile
├── Dockerfile
├── Meta-Llama-3-8B-Instruct.Q4_K_M.gguf
└── src
    └── main.rs
```

---

### Passo 3: Autenticação Inicial (AWS CLI)

Conecte o seu terminal Ubuntu à sua conta da AWS configurando as chaves que você acabou de gerar no Passo 1:

```bash
aws configure
```

Insira o seu Access Key ID, depois a sua Secret Access Key. Defina a região padrão como `us-east-1` e o formato de saída como `json`.

---

### Passo 4: Geração da Imagem Docker Local

Compile o código em Rust dentro do ambiente isolado do container e armazene a imagem localmente executando:

```bash
make build
```

Esse processo vai buildar o binário de release em Rust de forma otimizada e injetar o arquivo GGUF para dentro da imagem.

---

### Passo 5: Envio da Imagem para o Amazon ECR

Execute os comandos do seu Makefile para criar o repositório remoto na nuvem e fazer o upload do container:

```bash
make ecr-create

make push
```

Como o modelo está embutido dentro do container, o upload de alguns gigabytes levará alguns minutos dependendo da sua taxa de upload.

---

### Passo 6: Configuração de Permissões Críticas no IAM

Para que o SageMaker consiga subir a sua infraestrutura sem bloqueios de segurança, volte ao serviço IAM no navegador, clique em Users → `rodney` e garanta que ele possua estas três permissões configuradas na aba Permissions.

#### AmazonEC2ContainerRegistryFullAccess

Garante que o terminal possa criar repositórios e fazer push de imagens.

#### AmazonSageMakerFullAccess

Garante os direitos de criar modelos, configurações e endpoints no ecossistema SageMaker.

#### Política Inline PassRole

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

Permite que o usuário delegue permissões para a role utilizada pelo SageMaker.

---

### Passo 7: Deploy da Infraestrutura no Amazon SageMaker

Abra o seu arquivo Makefile e confirme se a variável ROLE_ARN aponta para a role correta.

Com tudo configurado, execute:

```bash
make deploy
```

Esse comando criará:

- Modelo SageMaker
- Endpoint Configuration
- Endpoint
- Infraestrutura de inferência

---

### Passo 8: Monitoramento do Endpoint

```bash
watch -n 2 "aws sagemaker describe-endpoint --endpoint-name rust-llm-endpoint --query EndpointStatus"
```

O status passará de:

```text
Creating
```

para:

```text
InService
```

Quando isso acontecer, o endpoint estará pronto para receber requisições.

---

### Passo 9: Teste de Inferência

Crie um arquivo `payload.json`:

```json
{
  "inputs": "Qual é a capital da Itália?"
}
```

Execute:

```bash
aws sagemaker-runtime invoke-endpoint \
    --endpoint-name rust-llm-endpoint \
    --body file://payload.json \
    --content-type application/json \
    output.json
```

Visualize a resposta:

```bash
cat output.json
```

Resultado esperado:

```json
{
  "generated_text": "A capital da Itália é Roma."
}
```

---

# 7. Principais Blocos de Código

## Carregamento do Modelo

```rust
let model = Llama::load(
    "Meta-Llama-3-8B-Instruct.Q4_K_M.gguf",
    device
)?;
```

### Explicação

<div align="justify">

Este trecho realiza a leitura do arquivo GGUF e inicializa toda a arquitetura Transformer dentro da memória do servidor.

Como o carregamento ocorre apenas durante a inicialização do container, as requisições posteriores conseguem reutilizar os pesos já carregados.

</div>

---

## Inicialização da API

```rust
let app = Router::new()
    .route("/invocations", post(inference));
```

### Explicação

<div align="justify">

Define a API HTTP utilizada pelo SageMaker para receber requisições de inferência.

Todas as chamadas enviadas ao endpoint serão encaminhadas para a função responsável pela geração de texto.

</div>

---

## Inferência

```rust
let output = model.generate(
    prompt,
    256
)?;
```

### Explicação

<div align="justify">

Executa a tokenização da entrada, realiza o forward pass através das camadas Transformer e gera a sequência de saída utilizando o modelo carregado.

</div>

---

## Resposta JSON

```rust
Json(json!({
    "generated_text": output
}))
```

### Explicação

<div align="justify">

Padroniza a resposta da API para integração com aplicações externas, sistemas de monitoramento e clientes HTTP.

</div>

---

# 8. Resultados Esperados

| Métrica | Valor |
|----------|----------|
| Linguagem | Rust |
| Framework | Axum |
| Runtime | Candle |
| Modelo | Llama 3 |
| Formato | GGUF |
| Deploy | SageMaker |
| Registry | Amazon ECR |
| Container | Docker |

---

# 9. Aprendizados do Projeto

<div align="justify">

Durante o desenvolvimento foram explorados conceitos relevantes de Machine Learning Engineering e MLOps.

</div>

- Deploy de modelos generativos
- LLM Serving
- Containerização
- Cloud Computing
- AWS SageMaker
- Amazon ECR
- Infraestrutura para IA
- Automação de Deploy
- APIs de Alta Performance
- Rust para Machine Learning

---

# 10. Trabalhos Futuros

<div align="justify">

A arquitetura foi projetada para permitir expansões futuras sem alterações significativas no fluxo principal.

</div>

- Streaming de tokens
- Batch inference
- Auto Scaling
- CloudWatch
- Prometheus
- Suporte a GPU
- KV Cache persistente
- Quantizações adicionais
- Deploy multi-região

---

# 11. Conclusão

<div align="justify">

Este projeto demonstra uma pipeline completa de deploy para Large Language Models utilizando Rust e AWS.

Além do desenvolvimento da API de inferência, a solução contempla containerização, gerenciamento de imagens, provisionamento de infraestrutura e disponibilização de um endpoint escalável pronto para uso em produção.

O projeto evidencia conhecimentos em engenharia de machine learning, cloud computing, MLOps e sistemas de inferência de alta performance.

</div>

---

## Competências Demonstradas

- Machine Learning Engineering
- MLOps
- LLM Serving
- AWS SageMaker
- Docker
- Amazon ECR
- Rust
- Axum
- Candle
- Cloud Computing
- APIs de Alta Performance
- Deploy de Modelos em Produção
````
