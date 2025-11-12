import 'dotenv/config';
import express, {} from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { ENV } from './env.js';
import { requireAuth } from './middleware/requireAuth.js';
import pagesRouter from './routes/pages.js';
import adminRouter from './routes/admin.js';
import profileRouter from './routes/profile.js';
import { AppError, formatErrorForLog } from './utils/errors.js';
const app = express();
// CORS configuration with origin allowlist
const allowedOrigins = ENV.ALLOWED_ORIGINS.split(',').map(origin => origin.trim());
app.use(cors({
    origin: (requestOrigin, callback) => {
        // Allow requests with no origin (mobile apps, Postman, etc.)
        if (!requestOrigin || allowedOrigins.includes(requestOrigin)) {
            callback(null, true);
        }
        else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true
}));
// Request body size limit
app.use(express.json({ limit: '10kb' }));
// Rate limiting
const generalLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: { error: 'Too many requests from this IP, please try again later' },
    standardHeaders: true,
    legacyHeaders: false,
});
const adminLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 50, // limit each IP to 50 requests per windowMs
    message: { error: 'Too many admin requests from this IP, please try again later' },
    standardHeaders: true,
    legacyHeaders: false,
});
app.get('/health', (_req, res) => res.json({ ok: true }));
app.use(generalLimiter);
app.use(requireAuth);
app.use('/pages', pagesRouter);
app.use('/profile', profileRouter);
app.use('/admin', adminLimiter, adminRouter);
// Global error handler
app.use((err, _req, res, _next) => {
    // Log the error with full details
    console.error('Unhandled error:', formatErrorForLog(err));
    // Handle AppError instances
    if (err instanceof AppError) {
        return res.status(err.statusCode).json(err.toJSON());
    }
    // Handle other errors
    const statusCode = err.statusCode || 500;
    return res.status(statusCode).json({
        error: process.env.NODE_ENV === 'production'
            ? 'Internal server error'
            : err.message
    });
});
// Start server with graceful shutdown
const server = app.listen(ENV.PORT, () => {
    console.log(`Environment validated successfully`);
    console.log(`API listening on :${ENV.PORT}`);
});
process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing HTTP server');
    server.close(() => {
        console.log('HTTP server closed');
        process.exit(0);
    });
});
process.on('SIGINT', () => {
    console.log('SIGINT signal received: closing HTTP server');
    server.close(() => {
        console.log('HTTP server closed');
        process.exit(0);
    });
});
//# sourceMappingURL=server.js.map