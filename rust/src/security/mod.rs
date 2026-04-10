use uuid::Uuid;

pub struct ApiKeyCipher;

impl ApiKeyCipher {
    pub fn encrypt(plain: &str) -> String {
        // Placeholder only: replace with aes-gcm/ring implementation.
        format!("enc:{}:{}", Uuid::new_v4(), plain.len())
    }
}
