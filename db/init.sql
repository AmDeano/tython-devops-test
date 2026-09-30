-- Exécuté automatiquement par l'image postgres au premier démarrage (volume vide).
CREATE TABLE IF NOT EXISTS messages (
    id         SERIAL PRIMARY KEY,
    content    VARCHAR(280) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO messages (content) VALUES ('Bienvenue sur Tython DevOps Demo 🚀');
