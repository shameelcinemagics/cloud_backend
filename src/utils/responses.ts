import type { Response } from 'express';

export const errorResponse = (res: Response, status: number, message: string) => {
  return res.status(status).json({ error: message });
};

export const unauthorized = (res: Response, message = 'Unauthorized') =>
  errorResponse(res, 401, message);

export const forbidden = (res: Response, message = 'Forbidden') =>
  errorResponse(res, 403, message);

export const badRequest = (res: Response, message: string) =>
  errorResponse(res, 400, message);

export const serverError = (res: Response, message = 'Internal server error') =>
  errorResponse(res, 500, message);

export const successResponse = <T>(res: Response, data: T) => {
  return res.json(data);
};
