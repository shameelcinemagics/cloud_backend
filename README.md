# VendCloud Backend

A secure, TypeScript-based REST API backend for VendCloud with role-based access control, built with Express.js and Supabase.

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Application](#running-the-application)
- [API Documentation](#api-documentation)
- [Database Schema](#database-schema)
- [Permission System](#permission-system)
- [Security Features](#security-features)
- [Development](#development)
- [Project Structure](#project-structure)

## Features

- JWT-based authentication via Supabase Auth
- Role-based access control (RBAC) with granular permissions
- CRUD permission system using bitmasks
- Secure CORS configuration with origin allowlist
- Rate limiting for API protection
- Input validation and sanitization
- Comprehensive error handling
- Type-safe TypeScript implementation
- Graceful shutdown handling

## Tech Stack

- **Runtime:** Node.js
- **Language:** TypeScript 5.9.3
- **Framework:** Express.js 5.1.0
- **Database:** PostgreSQL (via Supabase)
- **Authentication:** Supabase Auth (JWT tokens)
- **Rate Limiting:** express-rate-limit
- **CORS:** cors middleware

## Prerequisites

- Node.js (v18 or higher recommended)
- npm or yarn
- Supabase account and project
- PostgreSQL database (managed by Supabase)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd VendCloud_backend
```

2. Install dependencies:
```bash
npm install
```

3. Set up the database:
```bash
# Run the migration file on your Supabase database
# migrations/001_core.sql
```

## Configuration

Create a `.env` file in the root directory:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Server Configuration
PORT=8080

# CORS Configuration (comma-separated origins)
ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.com

# Admin Seed Configuration (for initial setup)
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=your-secure-password
```

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUPABASE_URL` | Your Supabase project URL | Yes |
| `SUPABASE_ANON_KEY` | Supabase anonymous key for client-side auth | Yes |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key for admin operations | Yes |
| `PORT` | Server port (default: 8080) | No |
| `ALLOWED_ORIGINS` | Comma-separated list of allowed CORS origins | No |
| `ADMIN_EMAIL` | Admin email for seed script | Only for seeding |
| `ADMIN_PASSWORD` | Admin password for seed script | Only for seeding |

## Running the Application

### Development Mode

Run with hot-reload:
```bash
npm run dev
```

### Production Mode

1. Build the TypeScript code:
```bash
npm run build
```

2. Start the server:
```bash
npm start
```

### Seed Admin User

Create an initial admin user:
```bash
npm run seed:admin
```

## API Documentation

### Base URL
```
http://localhost:8080
```

### Authentication

All endpoints except `/health` require a JWT bearer token in the Authorization header:
```
Authorization: Bearer <your-jwt-token>
```

### Endpoints

#### Health Check
```http
GET /health
```
No authentication required.

**Response:**
```json
{
  "ok": true
}
```

---

#### Get My Pages
```http
GET /pages/my-pages
```
Returns all pages the authenticated user has access to with their permission masks.

**Response:**
```json
{
  "pages": [
    {
      "page_slug": "dashboard",
      "perms_mask": 15
    },
    {
      "page_slug": "machines",
      "perms_mask": 2
    }
  ]
}
```

---

#### Create User (Admin)
```http
POST /admin/create-user
```
Requires UPDATE permission on "settings" page.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "email_confirm": true,
  "role_slug": "manager"  // Optional - assign role on creation
}
```

**Response:**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "created_at": "2025-01-02T10:00:00Z"
  },
  "role_assigned": true,
  "role_slug": "manager"
}
```

**Note:** If `role_slug` is provided, the user automatically gets that role's permissions via database trigger.

---

#### Create Role (Admin)
```http
POST /admin/create-role
```
Requires UPDATE permission on "settings" page.

**Request Body (Simple):**
```json
{
  "slug": "manager",
  "label": "Manager"
}
```

**Request Body (With Permissions - Recommended):**
```json
{
  "slug": "manager",
  "label": "Manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" }
  ]
}
```

**Validation:**
- `slug`: Required, lowercase alphanumeric with underscores or hyphens only
- `label`: Required, non-empty string
- `slug` must be unique
- `permissions`: Optional array of page permissions
  - `page_slug`: Must be valid page slug
  - `level`: Must be "view" or "admin"

**Response:**
```json
{
  "role": {
    "id": 2,
    "slug": "manager",
    "label": "Manager",
    "created_at": "2025-01-02T10:00:00Z"
  },
  "permissions_assigned": 3,
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" }
  ]
}
```

**Note:** Create role with permissions in one API call for streamlined workflow!

---

#### Set User Page Permissions (Admin)
```http
POST /admin/set-user-page
```
Requires UPDATE permission on "settings" page.

**Request Body:**
```json
{
  "user_id": "user-uuid",
  "page_slug": "dashboard",
  "level": "admin"
}
```

**Levels:**
- `view`: Read-only access (perms_mask: 2)
- `admin`: Full CRUD access (perms_mask: 15)
- `none`: Remove all permissions

**Response:**
```json
{
  "ok": true,
  "level": "admin",
  "perms_mask": 15
}
```

---

#### Assign System Admin (Admin)
```http
POST /admin/assign-admin
```
Promotes a user to system administrator role. Requires UPDATE permission on "settings" page.

**Request Body:**
```json
{
  "user_id": "user-uuid"
}
```

**Response:**
```json
{
  "ok": true
}
```

---

### Error Responses

All errors follow this format:
```json
{
  "error": "Error message"
}
```

**Status Codes:**
- `400` - Bad Request (invalid input)
- `401` - Unauthorized (missing or invalid token)
- `403` - Forbidden (insufficient permissions)
- `429` - Too Many Requests (rate limit exceeded)
- `500` - Internal Server Error

## Database Schema

### Tables

#### `roles`
Defines available roles in the system.
```sql
- id (uuid, primary key)
- slug (text, unique) -- e.g., "sys_admin"
- label (text) -- e.g., "System Administrator"
```

#### `user_roles`
Associates users with roles.
```sql
- user_id (uuid, references auth.users)
- role_id (uuid, references roles)
```

#### `pages`
Defines available pages/resources.
```sql
- id (uuid, primary key)
- slug (text, unique) -- e.g., "dashboard", "machines"
- label (text)
```

#### `user_page_perms`
Direct user-to-page permission assignments.
```sql
- user_id (uuid, references auth.users)
- page_id (uuid, references pages)
- perms_mask (integer) -- CRUD bitmask
```

### Views

#### `user_effective_page_perms`
Computed view that combines role-based and direct permissions.
```sql
- user_id (uuid)
- page_slug (text)
- perms_mask (integer)
```

## Permission System

### CRUD Bitmasks

Permissions use bitwise operations for efficient storage and checking:

```typescript
PERM.C = 1  // Create
PERM.R = 2  // Read
PERM.U = 4  // Update
PERM.D = 8  // Delete
```

### Permission Levels

- **View** (Read-only): `PERM.R` = 2
- **Admin** (Full access): `PERM.C | PERM.R | PERM.U | PERM.D` = 15

### Checking Permissions

```typescript
// Check if user has Update permission
if (has(user_perms_mask, PERM.U)) {
  // User can update
}

// Check for multiple permissions
if (has(user_perms_mask, PERM.R | PERM.U)) {
  // User can read and update
}
```

## Security Features

### 1. CORS Protection
- Origin allowlist configuration
- Credentials support for authenticated requests
- Configurable via `ALLOWED_ORIGINS` environment variable

### 2. Rate Limiting
- **General API**: 100 requests per 15 minutes per IP
- **Admin endpoints**: 50 requests per 15 minutes per IP

### 3. Input Validation
- UUID format validation
- Email format validation
- Password strength requirements (min 8 characters)
- Request body sanitization

### 4. Request Body Size Limit
- Maximum payload size: 10KB
- Prevents DoS attacks via large payloads

### 5. Error Handling
- Comprehensive try-catch blocks
- Sanitized error messages
- Global error handler middleware

### 6. Authentication
- JWT token-based authentication
- Token validation on every request
- Secure bearer token transmission

### 7. Row-Level Security (RLS)
- Database-level access control
- Automatic permission enforcement via Supabase

## Development

### Type Safety

The project uses TypeScript with strict mode enabled. Custom type extensions for Express:

```typescript
// src/types/express.d.ts
declare global {
  namespace Express {
    interface Request {
      user?: User;
    }
  }
}
```

### Utilities

#### Response Helpers
```typescript
import { badRequest, unauthorized, forbidden, serverError, successResponse } from './utils/responses.js';

// Usage
badRequest(res, 'Invalid input');
unauthorized(res, 'Missing token');
forbidden(res, 'Insufficient permissions');
serverError(res, 'Database error');
successResponse(res, { data: 'value' });
```

#### Validation Helpers
```typescript
import { isValidUUID, isValidEmail, isValidPassword, isNonEmptyString } from './utils/validation.js';

// Usage
if (!isValidUUID(user_id)) {
  return badRequest(res, 'Invalid user_id format');
}
```

### Scripts

```json
{
  "dev": "tsx watch src/server.ts",          // Development with hot reload
  "build": "tsc",                            // Compile TypeScript
  "start": "node dist/server.js",            // Run production build
  "seed:admin": "tsx scripts/seedAdmin.ts"   // Create admin user
}
```

## Project Structure

```
VendCloud_backend/
├── src/
│   ├── middleware/
│   │   ├── requireAuth.ts      # JWT authentication middleware
│   │   └── requirePerm.ts      # Permission checking middleware
│   ├── routes/
│   │   ├── admin.ts            # Admin endpoints
│   │   └── pages.ts            # Page/permission endpoints
│   ├── types/
│   │   └── express.d.ts        # Express type extensions
│   ├── utils/
│   │   ├── responses.ts        # Response helper functions
│   │   └── validation.ts       # Input validation utilities
│   ├── env.ts                  # Environment configuration
│   ├── perms.ts                # Permission constants and utilities
│   ├── server.ts               # Express app entry point
│   └── supabase.ts             # Supabase client initialization
├── migrations/
│   └── 001_core.sql            # Database schema and RLS policies
├── scripts/
│   └── seedAdmin.ts            # Admin user seeding script
├── dist/                       # Compiled JavaScript (generated)
├── .env                        # Environment variables (not in git)
├── package.json                # Project metadata
├── tsconfig.json               # TypeScript configuration
└── README.md                   # This file
```

## Best Practices

1. **Always validate user input** before processing
2. **Use helper functions** for consistent error handling
3. **Add try-catch blocks** around all async operations
4. **Check permissions** using middleware before sensitive operations
5. **Never expose sensitive data** in error messages
6. **Use environment variables** for configuration
7. **Keep dependencies updated** for security patches
8. **Use type-safe operations** with TypeScript
9. **Follow consistent code style** throughout the project
10. **Document new endpoints** and features

## License

[Your License Here]

## Contributing

[Contributing Guidelines Here]

## Support

For issues and questions, please [open an issue](https://github.com/your-repo/issues).
