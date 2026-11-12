import type { Request, Response, NextFunction  } from 'express';

type ErrorWithType = Error & { type?: string };

export function errorHandler(err: ErrorWithType, req: Request, res: Response, _next: NextFunction) {
  
  if(err.type === 'entity.parse.failed') {
    return res.status(400).json({
      success: false,
      error: { code: 'INVALID_JSON', message: 'Neispravan JSON.' },
    });
  }
  console.error(err);
  res.status(500).json({
    success: false,
    error: { code: 'INTERNAL_ERROR', message: 'Greška na serveru.' },
  });
}
