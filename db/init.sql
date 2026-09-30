-- postgres kaylanci had l fichier ghir f awel demarrage (mli l volume khawi)
CREATE TABLE IF NOT EXISTS messages (
    id         SERIAL PRIMARY KEY,
    content    VARCHAR(280) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO messages (content) VALUES ('Bienvenue sur Tython DevOps Demo 🚀');
