import { useEffect, useState } from 'react';

export default function App() {
  const [health, setHealth] = useState(null);
  const [messages, setMessages] = useState([]);
  const [content, setContent] = useState('');
  const [error, setError] = useState('');

  // kanjibo akhir 50 message mn l API
  const loadMessages = async () => {
    try {
      const res = await fetch('/api/messages');
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setMessages(await res.json());
      setError('');
    } catch (err) {
      setError(`Impossible de charger les messages : ${err.message}`);
    }
  };

  // f awel render : status dyal backend + messages
  useEffect(() => {
    fetch('/health')
      .then((res) => res.json())
      .then(setHealth)
      .catch(() => setHealth({ status: 'down' }));
    loadMessages();
  }, []);

  const submit = async (event) => {
    event.preventDefault();
    const res = await fetch('/api/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content }),
    });
    if (res.ok) {
      setContent('');
      loadMessages();
    } else {
      setError((await res.json()).error || 'Erreur');
    }
  };

  return (
    <main>
      <h1>Tython DevOps Demo</h1>
      <p className="status">
        Backend :{' '}
        <strong className={health?.status === 'ok' ? 'ok' : 'ko'}>
          {health ? health.status : '…'}
        </strong>
        {health?.version && <span> · version {health.version}</span>}
      </p>

      <form onSubmit={submit}>
        <input
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="Écrire un message…"
          maxLength={280}
          aria-label="Message"
        />
        <button type="submit" disabled={!content.trim()}>
          Envoyer
        </button>
      </form>

      {error && <p className="ko">{error}</p>}

      <ul>
        {messages.map((m) => (
          <li key={m.id}>
            <span>{m.content}</span>
            <time>{new Date(m.created_at).toLocaleString('fr-FR')}</time>
          </li>
        ))}
      </ul>
    </main>
  );
}
