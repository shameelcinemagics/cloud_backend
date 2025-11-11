import type { Request, Response, NextFunction } from 'express';
export declare function requirePerm(pageSlug: string, neededMask: number): (req: Request, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>> | undefined>;
//# sourceMappingURL=requirePerm.d.ts.map