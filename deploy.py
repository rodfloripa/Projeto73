import boto3
import time
from botocore.exceptions import ClientError

def clean_existing_resources(client, endpoint_name, config_name, model_name):
    print("🔄 Verificando e limpando recursos antigos para evitar conflitos...")
    
    # 1. Deletar Endpoint
    try:
        client.delete_endpoint(EndpointName=endpoint_name)
        print(f"🗑️  Endpoint antigo '{endpoint_name}' removido.")
        time.sleep(2)
    except ClientError as e:
        if 'ValidationException' not in str(e): print(f"⚠️  {e}")

    # 2. Deletar Endpoint Config
    try:
        client.delete_endpoint_config(EndpointConfigName=config_name)
        print(f"🗑️  EndpointConfig antiga '{config_name}' removida.")
        time.sleep(2)
    except ClientError as e:
        if 'ValidationException' not in str(e): print(f"⚠️  {e}")

    # 3. Deletar Modelo antigo se existir
    try:
        client.delete_model(ModelName=model_name)
        print(f"🗑️  Modelo antigo '{model_name}' removido.")
    except ClientError as e:
        if 'ValidationException' not in str(e): print(f"⚠️  {e}")

def main():
    # Inicializa o cliente nativo do SageMaker via boto3 (usando a região da Virgínia)
    region = "us-east-1"
    client = boto3.client('sagemaker', region_name=region)

    role_arn = 'arn:aws:iam::634510061385:role/SageMakerExecutionRole'
    image_uri = '634510061385.dkr.ecr.us-east-1.amazonaws.com/sagemaker-rust-llm:latest'
    
    model_name = 'rust-llm-model-v3'
    config_name = 'rust-llm-config-v2'
    endpoint_name = 'rust-llm-endpoint'

    # Executa a limpeza preventiva do ambiente que falhou antes
    clean_existing_resources(client, endpoint_name, config_name, model_name)
    time.sleep(5) # Aguarda a AWS processar a remoção

    print(f"📦 1/3: Criando objeto de modelo no SageMaker apontando para o ECR...")
    client.create_model(
        ModelName=model_name,
        PrimaryContainer={
            'Image': image_uri,
            'Environment': {
                'PORT': '8080',
                'RUST_BACKTRACE': '1',
                'RUST_LOG': 'info'
            }
        },
        ExecutionRoleArn=role_arn
    )

    print(f"🛠️  2/3: Criando configuração do Endpoint (Ativando Abordagem 2: 10 min timeout)...")
    client.create_endpoint_config(
        EndpointConfigName=config_name,
        ProductionVariants=[
            {
                'VariantName': 'AllTraffic',
                'ModelName': model_name,
                'InitialInstanceCount': 1,
                'InstanceType': 'ml.g5.xlarge',
                # ABORDAGEM 2: Informa à API nativa o tempo máximo de tolerância para o health check do /ping
                'ContainerStartupHealthCheckTimeoutInSeconds': 600
            }
        ]
    )

    print(f"🚀 3/3: Publicando o Endpoint na AWS SageMaker...")
    client.create_endpoint(
        EndpointName=endpoint_name,
        EndpointConfigName=config_name
    )

    print("\n==========================================================================")
    print("⏳ Deploy iniciado com sucesso! O endpoint está sendo provisionado.")
    print("Execute o comando abaixo para acompanhar o status até ficar 'InService':")
    print(f"watch -n 5 \"aws sagemaker describe-endpoint --endpoint-name {endpoint_name} --query EndpointStatus\"")
    print("==========================================================================")

if __name__ == "__main__":
    main()
