# ======================= CONFIGURAÇÕES =======================
REGION ?= us-east-1
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
REPO_NAME ?= sagemaker-rust-llm
IMAGE_TAG ?= latest
ECR_URI = $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/$(REPO_NAME)

MODEL_NAME ?= rust-llm-model
CONFIG_NAME ?= rust-llm-config
ENDPOINT_NAME ?= rust-llm-endpoint
INSTANCE_TYPE ?= ml.m5.xlarge
ROLE_ARN ?= arn:aws:iam::$(ACCOUNT_ID):role/SageMakerExecutionRole

# Nota: Alteramos o INSTANCE_TYPE para 'ml.m5.large' (CPU) temporariamente neste passo 
# para você economizar nos testes iniciais, já que ainda não colocamos a GPU pesada do Llama.

# ======================= COMANDOS ECR =======================
.PHONY: ecr-create ecr-login build push

ecr-create:
	aws ecr create-repository --repository-name $(REPO_NAME) --region $(REGION) || true

ecr-login:
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(ECR_URI)

build:
	docker build -t $(REPO_NAME):$(IMAGE_TAG) .

push: ecr-login build
	docker tag $(REPO_NAME):$(IMAGE_TAG) $(ECR_URI):$(IMAGE_TAG)
	docker push $(ECR_URI):$(IMAGE_TAG)

# ======================= SAGEMAKER DEPLOY =======================
.PHONY: create-model create-config create-endpoint deploy status

create-model:
	aws sagemaker create-model \
		--model-name $(MODEL_NAME) \
		--primary-container Image=$(ECR_URI):$(IMAGE_TAG) \
		--execution-role-arn $(ROLE_ARN) \
		--region $(REGION)

create-config:
	aws sagemaker create-endpoint-config \
		--endpoint-config-name $(CONFIG_NAME) \
		--production-variants VariantName=AllTraffic,ModelName=$(MODEL_NAME),InstanceType=$(INSTANCE_TYPE),InitialInstanceCount=1 \
		--region $(REGION)

create-endpoint:
	aws sagemaker create-endpoint \
		--endpoint-name $(ENDPOINT_NAME) \
		--endpoint-config-name $(CONFIG_NAME) \
		--region $(REGION)

deploy: push create-model create-config create-endpoint
	@echo "Deploy iniciado. Aguardando endpoint ficar InService..."
	@aws sagemaker wait endpoint-in-service --endpoint-name $(ENDPOINT_NAME) --region $(REGION)
	@echo "Endpoint pronto: $(ENDPOINT_NAME)"

destroy:
	@echo "🛑 Iniciando a destruição completa dos recursos do SageMaker..."
	@aws sagemaker delete-endpoint --endpoint-name rust-llm-endpoint
	@echo "🗑️  Endpoint 'rust-llm-endpoint' removido (Cobrança interrompida)."
	@aws sagemaker delete-endpoint-config --endpoint-config-name rust-llm-config-v2
	@echo "🗑️  Configuração 'rust-llm-config-v2' removida."
	@aws sagemaker delete-model --model-name rust-llm-model-v3
	@echo "🗑️  Modelo 'rust-llm-model-v3' removido."
	@echo "🔍 Verificando status atual na AWS..."
	@aws sagemaker list-endpoints --query "Endpoints[?EndpointStatus=='InService'].EndpointName"
	@echo "🎉 Limpeza concluída! Sua conta está segura contra cobranças."

status:
	aws sagemaker describe-endpoint --endpoint-name $(ENDPOINT_NAME) --region $(REGION) --query 'EndpointStatus'

# ======================= INFERÊNCIA =======================
.PHONY: invoke

invoke:
	@echo '{"inputs": "Testando container Rust no SageMaker", "parameters": {"max_new_tokens": 64}}' > payload.json
	aws sagemaker-runtime invoke-endpoint \
		--endpoint-name $(ENDPOINT_NAME) \
		--content-type application/json \
		--body fileb://payload.json \
		--region $(REGION) \
		response.json
	@cat response.json && echo ""

# ======================= CLEANUP (DELETAR TUDO) =======================
.PHONY: delete-endpoint delete-config delete-model delete-ecr-image delete-ecr clean list

delete-endpoint:
	aws sagemaker delete-endpoint --endpoint-name $(ENDPOINT_NAME) --region $(REGION) || true

delete-config:
	aws sagemaker delete-endpoint-config --endpoint-config-name $(CONFIG_NAME) --region $(REGION) || true

delete-model:
	aws sagemaker delete-model --model-name $(MODEL_NAME) --region $(REGION) || true

delete-ecr-image:
	aws ecr batch-delete-image --repository-name $(REPO_NAME) --image-ids imageTag=$(IMAGE_TAG) --region $(REGION) || true

delete-ecr:
	aws ecr delete-repository --repository-name $(REPO_NAME) --force --region $(REGION) || true

clean: delete-endpoint delete-config delete-model delete-ecr-image delete-ecr
	@echo "Tudo limpo com sucesso! Nenhuma cobrança ativa."

list:
	@echo "=== Endpoints ==="
	@aws sagemaker list-endpoints --region $(REGION) --query 'Endpoints[*].[EndpointName,EndpointStatus]' --output table
	@echo "=== Models ==="
	@aws sagemaker list-models --region $(REGION) --query 'Models[*].[ModelName]' --output table
