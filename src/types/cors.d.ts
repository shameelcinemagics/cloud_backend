declare module 'cors' {
  import type { RequestHandler } from 'express';

  interface CorsOptions {
    origin?: boolean | string | RegExp | Array<string | RegExp>;
    methods?: string | string[];
    allowedHeaders?: string | string[];
    exposedHeaders?: string | string[];
    credentials?: boolean;
    maxAge?: number;
    preflightContinue?: boolean;
    optionsSuccessStatus?: number;
  }

  type CorsRequestHandler = (options?: CorsOptions) => RequestHandler;

  const cors: CorsRequestHandler;
  export default cors;
  export { cors, CorsOptions, CorsRequestHandler };
}
