/**
 * Standard error codes used throughout the application
 */
export const ErrorCodes = {
    // Authentication errors (1xxx)
    MISSING_TOKEN: 'AUTH_1001',
    INVALID_TOKEN: 'AUTH_1002',
    UNAUTHENTICATED: 'AUTH_1003',
    // Authorization errors (2xxx)
    INSUFFICIENT_PERMISSIONS: 'AUTHZ_2001',
    FORBIDDEN: 'AUTHZ_2002',
    // Validation errors (3xxx)
    INVALID_INPUT: 'VAL_3001',
    INVALID_UUID: 'VAL_3002',
    INVALID_EMAIL: 'VAL_3003',
    INVALID_PASSWORD: 'VAL_3004',
    INVALID_SLUG: 'VAL_3005',
    MISSING_REQUIRED_FIELD: 'VAL_3006',
    // Resource errors (4xxx)
    NOT_FOUND: 'RES_4001',
    ALREADY_EXISTS: 'RES_4002',
    CONFLICT: 'RES_4003',
    // Database errors (5xxx)
    DATABASE_ERROR: 'DB_5001',
    FOREIGN_KEY_VIOLATION: 'DB_5002',
    UNIQUE_VIOLATION: 'DB_5003',
    CHECK_VIOLATION: 'DB_5004',
    // System errors (9xxx)
    INTERNAL_SERVER_ERROR: 'SYS_9001',
    SERVICE_UNAVAILABLE: 'SYS_9002',
};
/**
 * Custom application error with error code
 */
export class AppError extends Error {
    code;
    statusCode;
    details;
    constructor(code, message, statusCode = 500, details) {
        super(message);
        this.code = code;
        this.statusCode = statusCode;
        this.details = details;
        this.name = 'AppError';
        Error.captureStackTrace(this, this.constructor);
    }
    toJSON() {
        const result = {
            error: this.message,
            code: this.code,
        };
        if (this.details) {
            result.details = this.details;
        }
        return result;
    }
}
/**
 * Parse PostgreSQL error codes and convert to AppError
 */
export function parsePostgresError(error) {
    // PostgreSQL error codes: https://www.postgresql.org/docs/current/errcodes-appendix.html
    const pgCode = error.code;
    const message = error.message;
    switch (pgCode) {
        // Unique violation (23505)
        case '23505':
            return new AppError(ErrorCodes.UNIQUE_VIOLATION, 'A record with this value already exists', 409, { originalError: message });
        // Foreign key violation (23503)
        case '23503':
            return new AppError(ErrorCodes.FOREIGN_KEY_VIOLATION, 'Referenced record does not exist', 400, { originalError: message });
        // Check violation (23514)
        case '23514':
            return new AppError(ErrorCodes.CHECK_VIOLATION, 'Value does not meet constraints', 400, { originalError: message });
        // Not null violation (23502)
        case '23502':
            return new AppError(ErrorCodes.MISSING_REQUIRED_FIELD, 'Required field is missing', 400, { originalError: message });
        // Default database error
        default:
            return new AppError(ErrorCodes.DATABASE_ERROR, 'Database operation failed', 500, { code: pgCode, originalError: message });
    }
}
/**
 * Supabase-specific error handler
 */
export function handleSupabaseError(error) {
    // Handle PostgrestError
    if (error?.code && error?.message) {
        return parsePostgresError(error);
    }
    // Handle AuthError
    if (error?.__isAuthError) {
        const authCode = error.code;
        switch (authCode) {
            case 'invalid_credentials':
                return new AppError(ErrorCodes.INVALID_TOKEN, 'Invalid credentials', 401);
            case 'user_not_found':
                return new AppError(ErrorCodes.NOT_FOUND, 'User not found', 404);
            case 'email_exists':
                return new AppError(ErrorCodes.ALREADY_EXISTS, 'Email already exists', 409);
            default:
                return new AppError(ErrorCodes.DATABASE_ERROR, error.message || 'Authentication error', error.status || 500);
        }
    }
    // Generic error
    return new AppError(ErrorCodes.INTERNAL_SERVER_ERROR, error?.message || 'An unexpected error occurred', 500);
}
/**
 * Format error for logging (excludes sensitive info)
 */
export function formatErrorForLog(error) {
    const baseLog = {
        name: error.name,
        message: error.message,
        stack: error.stack,
    };
    if (error instanceof AppError) {
        return {
            ...baseLog,
            code: error.code,
            statusCode: error.statusCode,
            details: error.details,
        };
    }
    return baseLog;
}
/**
 * Determine if error should be retried
 */
export function isRetryableError(error) {
    // Network errors, timeouts, and certain database errors can be retried
    const retryableCodes = [
        ErrorCodes.SERVICE_UNAVAILABLE,
        ErrorCodes.DATABASE_ERROR, // Some DB errors may be transient
    ];
    return retryableCodes.includes(error.code);
}
/**
 * Create validation error
 */
export function validationError(field, message) {
    return new AppError(ErrorCodes.INVALID_INPUT, message, 400, { field });
}
/**
 * Create not found error
 */
export function notFoundError(resource) {
    return new AppError(ErrorCodes.NOT_FOUND, `${resource} not found`, 404);
}
/**
 * Create already exists error
 */
export function alreadyExistsError(resource) {
    return new AppError(ErrorCodes.ALREADY_EXISTS, `${resource} already exists`, 409);
}
/**
 * Create permission error
 */
export function permissionError(message = 'Insufficient permissions') {
    return new AppError(ErrorCodes.INSUFFICIENT_PERMISSIONS, message, 403);
}
/**
 * Create authentication error
 */
export function authenticationError(message = 'Authentication required') {
    return new AppError(ErrorCodes.UNAUTHENTICATED, message, 401);
}
//# sourceMappingURL=errors.js.map