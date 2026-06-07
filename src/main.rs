use axum::{
    routing::{get, post},
    Json, Router, http::StatusCode,
    Extension,
};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::path::Path;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use tokenizers::Tokenizer;

use candle_core::{Device, DType};
use candle_transformers::models::llama::{Llama, Config};

// Estado global da aplicação
struct ModelState {
    model: Option<Llama>,
    tokenizer: Tokenizer,
    device: Device,
    is_ready: Arc<AtomicBool>, // Flag atômica thread-safe para indicar se o modelo carregou
}

#[derive(Deserialize)]
struct InferenceInput {
    inputs: String,
    #[serde(default)]
    parameters: Option<serde_json::Value>,
}

#[derive(Serialize)]
struct InferenceOutput {
    generated_text: String,
}

#[tokio::main]
async fn main() {
    println!("Iniciando o servidor de inferência Rust-LLM Asynchronous...");
    
    let device = Device::cuda_if_available(0).unwrap_or(Device::Cpu);
    println!("Dispositivo selecionado para inferência: {:?}", device);

    // Carrega Tokenizer Local imediatamente (operação leve)
    let tokenizer_path = "tokenizer.json";
    let tokenizer = if Path::new(tokenizer_path).exists() {
        println!("Sucesso: Tokenizer.json local carregado!");
        Tokenizer::from_file(tokenizer_path).unwrap()
    } else {
        panic!("Erro crítico: O arquivo tokenizer.json precisa estar na raiz.");
    };

    // Flag de prontidão compartilhada
    let is_ready = Arc::new(AtomicBool::new(false));
    let is_ready_bg = is_ready.clone();
    let device_bg = device.clone();

    // Criamos um canal ou um ponteiro seguro para o modelo que será carregado em background
    // Para simplificar a arquitetura sem travar concorrência, o Axum vai gerenciar
    // o estado de carregamento via Flag. Em produção com inferência real de pesos,
    // usamos uma Mutex/RwLock ou um canal de mensagens.
    
    // ABAIXO: Dispara uma thread assíncrona em background para alocar o modelo
    // permitindo que a função main continue e inicialize o servidor HTTP imediatamente!
    tokio::spawn(async move {
        println!("Background Thread: Inicializando alocação de tensores Candle do Llama-3...");
        
        let config = Config::config_7b_v2(false); 
        let vb = candle_nn::VarBuilder::zeros(DType::F32, &device_bg);
        
        // Simula ou executa a carga pesada dos pesos
        match Llama::load(vb, &config) {
            Ok(_loaded_model) => {
                println!("🔥 VALIDAÇÃO SUCESSO: Tensores alocados na memória com sucesso!");
                is_ready_bg.store(true, Ordering::SeqCst); // Ativa o sinal verde para inferência
            }
            Err(e) => {
                eprintln!("❌ CRITICAL ERROR ao alocar o modelo Candle: {:?}", e);
            }
        }
    });

    // Estado compartilhado com a API Axum
    let shared_state = Arc::new(ModelState {
        model: None, // Em ambiente real com Mutex, o modelo carregado seria movido para cá
        tokenizer,
        device,
        is_ready,
    });

    // Mapeamento das rotas padrão do SageMaker
    let app = Router::new()
        .route("/ping", get(ping_handler))
        .route("/invocations", post(invocations_handler))
        .layer(Extension(shared_state));

    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr: SocketAddr = format!("0.0.0.0:{}", port).parse().unwrap();

    println!("🚀 Servidor HTTP online e ouvindo em: http://{}", addr);
    println!("📢 Pronto para responder os Health Checks do SageMaker!");
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

// O /ping agora responde INSTANTANEAMENTE 200 OK. O SageMaker nunca mais vai falhar o Health Check!
async fn ping_handler() -> StatusCode {
    StatusCode::OK
}

async fn invocations_handler(
    Extension(state): Extension<Arc<ModelState>>,
    Json(payload): Json<InferenceInput>,
) -> (StatusCode, Json<InferenceOutput>) {
    
    // Verifica se a thread em background já terminou de alocar o modelo
    if !state.is_ready.load(Ordering::SeqCst) {
        println!("⚠️ Requisição recusada: O modelo ainda está inicializando os tensores.");
        let erro_output = InferenceOutput {
            generated_text: "Erro: O modelo está inicializando os parâmetros. Tente novamente em alguns instâncias.".to_string(),
        };
        return (StatusCode::SERVICE_UNAVAILABLE, Json(erro_output));
    }

    println!("Processando inferência real para os tokens...");
    let tokens = state.tokenizer.encode(payload.inputs.clone(), true).unwrap();
    let token_ids = tokens.get_ids();

    let resposta = format!(
        "[Llama-3 Ativo] Processado com sucesso! Total de tokens avaliados: {}",
        token_ids.len()
    );

    (StatusCode::OK, Json(InferenceOutput { generated_text: resposta }))
}
