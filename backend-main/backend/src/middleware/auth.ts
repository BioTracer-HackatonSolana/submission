import { Request, Response, NextFunction } from 'express';

export const requireApiKey = (req: Request, res: Response, next: NextFunction): void => {
  const apiKey = req.headers['x-api-key'];
  const validApiKey = process.env.API_SECRET_KEY;

  // Se a API_SECRET_KEY não estiver configurada no servidor, podemos optar por negar
  // tudo ou aceitar (em modo dev). Para segurança, vamos negar se não bater.
  if (!validApiKey) {
    console.error('CRITICAL: API_SECRET_KEY is not set in the environment variables.');
    res.status(500).json({ error: 'Server configuration error' });
    return;
  }

  if (!apiKey || apiKey !== validApiKey) {
    res.status(401).json({ error: 'Unauthorized: Invalid or missing API Key' });
    return;
  }

  next();
};
