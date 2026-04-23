const express = require('express');
const axios = require('axios');
const path = require('path');
const app = express();

const API_URL = process.env.API_URL || 'http://localhost:8000';
const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';

app.disable('x-powered-by');
app.use(express.json());
app.use(express.static(path.join(__dirname, 'views')));

app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'index.html'));
});

app.post('/submit', async (req, res) => {
  try {
    const response = await axios.post(`${API_URL}/jobs`, null, { timeout: 5000 });
    res.status(response.status).json(response.data);
  } catch (err) {
    if (err.response) {
      res.status(err.response.status).json(err.response.data);
      return;
    }

    res.status(502).json({ error: 'api unavailable' });
  }
});

app.get('/status/:id', async (req, res) => {
  try {
    const response = await axios.get(`${API_URL}/jobs/${req.params.id}`, { timeout: 5000 });
    res.status(response.status).json(response.data);
  } catch (err) {
    if (err.response) {
      res.status(err.response.status).json(err.response.data);
      return;
    }

    res.status(502).json({ error: 'api unavailable' });
  }
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.listen(PORT, HOST, () => {
  console.log(`Frontend running on ${HOST}:${PORT}`);
});
