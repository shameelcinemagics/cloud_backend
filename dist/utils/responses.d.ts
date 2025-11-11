import type { Response } from 'express';
export declare const errorResponse: (res: Response, status: number, message: string) => Response<any, Record<string, any>>;
export declare const unauthorized: (res: Response, message?: string) => Response<any, Record<string, any>>;
export declare const forbidden: (res: Response, message?: string) => Response<any, Record<string, any>>;
export declare const badRequest: (res: Response, message: string) => Response<any, Record<string, any>>;
export declare const serverError: (res: Response, message?: string) => Response<any, Record<string, any>>;
export declare const successResponse: <T>(res: Response, data: T) => Response<any, Record<string, any>>;
//# sourceMappingURL=responses.d.ts.map