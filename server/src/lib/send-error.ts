import { Response } from 'express';

/**
 * Shared error responder that reproduces the exact inline pattern used across
 * route catch blocks: `res.status(err.statusCode || 500).json({ error: err.message })`.
 *
 * No new behavior is added — this is a mechanical extraction of the existing shape.
 */
export function sendError(res: Response, err: any): void {
  const status = err.statusCode || 500;
  res.status(status).json({ error: err.message });
}
