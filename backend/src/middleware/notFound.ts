import type {Request, Response} from "express";

export function notFound(req: Request, res: Response) {
  res.status(404).json({
    success: false,
    error: { code: 'NOT_FOUND', message: `Ruta ${req.method} ${req.path} ne postoji.` },
  });
}