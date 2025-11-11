import type { PostgrestError } from '@supabase/supabase-js';
/**
 * Standard error codes used throughout the application
 */
export declare const ErrorCodes: {
    readonly MISSING_TOKEN: "AUTH_1001";
    readonly INVALID_TOKEN: "AUTH_1002";
    readonly UNAUTHENTICATED: "AUTH_1003";
    readonly INSUFFICIENT_PERMISSIONS: "AUTHZ_2001";
    readonly FORBIDDEN: "AUTHZ_2002";
    readonly INVALID_INPUT: "VAL_3001";
    readonly INVALID_UUID: "VAL_3002";
    readonly INVALID_EMAIL: "VAL_3003";
    readonly INVALID_PASSWORD: "VAL_3004";
    readonly INVALID_SLUG: "VAL_3005";
    readonly MISSING_REQUIRED_FIELD: "VAL_3006";
    readonly NOT_FOUND: "RES_4001";
    readonly ALREADY_EXISTS: "RES_4002";
    readonly CONFLICT: "RES_4003";
    readonly DATABASE_ERROR: "DB_5001";
    readonly FOREIGN_KEY_VIOLATION: "DB_5002";
    readonly UNIQUE_VIOLATION: "DB_5003";
    readonly CHECK_VIOLATION: "DB_5004";
    readonly INTERNAL_SERVER_ERROR: "SYS_9001";
    readonly SERVICE_UNAVAILABLE: "SYS_9002";
};
/**
 * Custom application error with error code
 */
export declare class AppError extends Error {
    code: string;
    statusCode: number;
    details?: unknown | undefined;
    constructor(code: string, message: string, statusCode?: number, details?: unknown | undefined);
    toJSON(): {
        error: string;
        code: string;
        details?: unknown;
    };
}
/**
 * Parse PostgreSQL error codes and convert to AppError
 */
export declare function parsePostgresError(error: PostgrestError): AppError;
/**
 * Supabase-specific error handler
 */
export declare function handleSupabaseError(error: any): AppError;
/**
 * Format error for logging (excludes sensitive info)
 */
export declare function formatErrorForLog(error: Error | AppError): Record<string, unknown>;
/**
 * Determine if error should be retried
 */
export declare function isRetryableError(error: AppError): boolean;
/**
 * Create validation error
 */
export declare function validationError(field: string, message: string): AppError;
/**
 * Create not found error
 */
export declare function notFoundError(resource: string): AppError;
/**
 * Create already exists error
 */
export declare function alreadyExistsError(resource: string): AppError;
/**
 * Create permission error
 */
export declare function permissionError(message?: string): AppError;
/**
 * Create authentication error
 */
export declare function authenticationError(message?: string): AppError;
//# sourceMappingURL=errors.d.ts.map