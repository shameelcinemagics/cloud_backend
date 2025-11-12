# User Profiles Guide

## Overview

The VendCloud backend now includes a **profiles table** that stores additional user information for all users, including admins. Profiles are automatically created and synced with the authentication system.

---

## Features

✅ **Auto-created on user signup** - Database trigger creates profile automatically
✅ **Role syncing** - Profile role_slug syncs with user_metadata.role
✅ **Admin & user endpoints** - Admins can manage all profiles, users can manage their own
✅ **Pagination support** - List profiles with limit/offset
✅ **Secure RLS policies** - Users can only read/update their own profile

---

## Database Schema

### profiles Table

```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  phone TEXT,
  role_slug TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Columns:**
- `id` - User ID (references auth.users.id)
- `email` - User email (synced from auth.users)
- `full_name` - User's full name
- `avatar_url` - URL to user's avatar image
- `phone` - User's phone number
- `role_slug` - User's role (synced from user_metadata)
- `created_at` - Profile creation timestamp
- `updated_at` - Last update timestamp

---

## How It Works

### Automatic Profile Creation

When a user is created (via `/admin/create-user` or Supabase Auth):

1. **User created in auth.users**
2. **Database trigger fires** → `on_auth_user_created`
3. **Profile auto-created** in profiles table with:
   - id = user.id
   - email = user.email
   - role_slug = user_metadata.role

### Automatic Role Syncing

When user_metadata.role is updated:

1. **user_metadata updated** in auth.users
2. **Database trigger fires** → `on_auth_user_metadata_updated`
3. **Profile.role_slug synced** automatically

---

## API Endpoints

### User Endpoints (Self-Service)

#### Get My Profile
```http
GET /profile/me
Authorization: Bearer <user-token>
```

**Response:**
```json
{
  "profile": {
    "id": "user-uuid",
    "email": "user@example.com",
    "full_name": "John Doe",
    "avatar_url": "https://example.com/avatar.jpg",
    "phone": "+1234567890",
    "role_slug": "manager",
    "created_at": "2025-01-03T10:00:00Z",
    "updated_at": "2025-01-03T10:00:00Z"
  }
}
```

---

#### Update My Profile
```http
PUT /profile/me
Authorization: Bearer <user-token>
```

**Request Body:**
```json
{
  "full_name": "John Smith",
  "avatar_url": "https://example.com/new-avatar.jpg",
  "phone": "+1234567890"
}
```

**Response:**
```json
{
  "profile": {
    "id": "user-uuid",
    "email": "user@example.com",
    "full_name": "John Smith",
    "avatar_url": "https://example.com/new-avatar.jpg",
    "phone": "+1234567890",
    "role_slug": "manager",
    "created_at": "2025-01-03T10:00:00Z",
    "updated_at": "2025-01-03T11:30:00Z"
  }
}
```

**Notes:**
- Users can only update their own profile
- Users cannot update `email`, `role_slug`, `id`, or timestamps
- All fields are optional - only send fields you want to update

---

### Admin Endpoints

#### Get User Profile
```http
GET /admin/profile/:user_id
Authorization: Bearer <admin-token>
```

**Permissions Required:** READ on "users" page

**Response:**
```json
{
  "profile": {
    "id": "user-uuid",
    "email": "user@example.com",
    "full_name": "John Doe",
    "avatar_url": "https://example.com/avatar.jpg",
    "phone": "+1234567890",
    "role_slug": "manager",
    "created_at": "2025-01-03T10:00:00Z",
    "updated_at": "2025-01-03T10:00:00Z"
  }
}
```

---

#### Update User Profile
```http
PUT /admin/profile/:user_id
Authorization: Bearer <admin-token>
```

**Permissions Required:** UPDATE on "users" page

**Request Body:**
```json
{
  "full_name": "John Smith",
  "avatar_url": "https://example.com/avatar.jpg",
  "phone": "+1234567890"
}
```

**Response:**
```json
{
  "profile": {
    "id": "user-uuid",
    "email": "user@example.com",
    "full_name": "John Smith",
    "avatar_url": "https://example.com/avatar.jpg",
    "phone": "+1234567890",
    "role_slug": "manager",
    "created_at": "2025-01-03T10:00:00Z",
    "updated_at": "2025-01-03T11:45:00Z"
  }
}
```

---

#### Get All Profiles (Paginated)
```http
GET /admin/profiles?limit=50&offset=0
Authorization: Bearer <admin-token>
```

**Permissions Required:** READ on "users" page

**Query Parameters:**
- `limit` (optional, default: 50) - Number of profiles to return
- `offset` (optional, default: 0) - Number of profiles to skip

**Response:**
```json
{
  "profiles": [
    {
      "id": "user-uuid-1",
      "email": "user1@example.com",
      "full_name": "John Doe",
      "avatar_url": "https://example.com/avatar1.jpg",
      "phone": "+1234567890",
      "role_slug": "manager",
      "created_at": "2025-01-03T10:00:00Z",
      "updated_at": "2025-01-03T10:00:00Z"
    },
    {
      "id": "user-uuid-2",
      "email": "user2@example.com",
      "full_name": "Jane Smith",
      "avatar_url": null,
      "phone": null,
      "role_slug": "employee",
      "created_at": "2025-01-03T09:00:00Z",
      "updated_at": "2025-01-03T09:00:00Z"
    }
  ],
  "total": 125,
  "limit": 50,
  "offset": 0
}
```

---

## Complete Workflow

### 1. Create User with Profile

When you create a user, the profile is auto-created:

```bash
POST /admin/create-user
{
  "email": "newuser@example.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}
```

**What happens:**
1. User created in `auth.users` with `user_metadata.role = "manager"`
2. Trigger auto-creates profile with:
   - id = new user ID
   - email = "newuser@example.com"
   - role_slug = "manager"
3. User assigned to role in `user_roles` table
4. Permissions granted from role

---

### 2. User Updates Their Profile

```bash
# User logs in and gets JWT token

# User updates their profile
PUT /profile/me
Authorization: Bearer <user-token>
{
  "full_name": "John Doe",
  "phone": "+1234567890"
}
```

---

### 3. Admin Updates User Profile

```bash
# Admin can update any user's profile
PUT /admin/profile/user-uuid-123
Authorization: Bearer <admin-token>
{
  "full_name": "Updated Name",
  "avatar_url": "https://example.com/avatar.jpg"
}
```

---

### 4. Admin Updates User Role (Syncs to Profile)

```bash
POST /admin/update-user-role
{
  "user_id": "user-uuid-123",
  "role_slug": "senior_manager"
}
```

**What happens:**
1. `user_metadata.role` updated to "senior_manager"
2. `user_roles` table updated
3. **Trigger auto-syncs** `profiles.role_slug` to "senior_manager"
4. User permissions replaced with new role's permissions

---

## Frontend Examples

### React - Display User Profile

```jsx
import { useState, useEffect } from 'react';
import { supabase } from './supabaseClient';

function UserProfile() {
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchProfile();
  }, []);

  const fetchProfile = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const token = session?.access_token;

      const response = await fetch('http://localhost:8080/profile/me', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });

      const data = await response.json();
      setProfile(data.profile);
    } catch (error) {
      console.error('Error fetching profile:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div>Loading...</div>;
  if (!profile) return <div>Profile not found</div>;

  return (
    <div>
      <h1>My Profile</h1>
      <p>Email: {profile.email}</p>
      <p>Name: {profile.full_name || 'Not set'}</p>
      <p>Phone: {profile.phone || 'Not set'}</p>
      <p>Role: {profile.role_slug}</p>
      {profile.avatar_url && (
        <img src={profile.avatar_url} alt="Avatar" />
      )}
    </div>
  );
}
```

---

### React - Update Profile Form

```jsx
import { useState } from 'react';
import { supabase } from './supabaseClient';

function EditProfile({ profile, onUpdate }) {
  const [formData, setFormData] = useState({
    full_name: profile.full_name || '',
    phone: profile.phone || '',
    avatar_url: profile.avatar_url || ''
  });
  const [saving, setSaving] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);

    try {
      const { data: { session } } = await supabase.auth.getSession();
      const token = session?.access_token;

      const response = await fetch('http://localhost:8080/profile/me', {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
      });

      const data = await response.json();
      onUpdate(data.profile);
      alert('Profile updated successfully!');
    } catch (error) {
      console.error('Error updating profile:', error);
      alert('Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <div>
        <label>Full Name:</label>
        <input
          type="text"
          value={formData.full_name}
          onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
        />
      </div>

      <div>
        <label>Phone:</label>
        <input
          type="tel"
          value={formData.phone}
          onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
        />
      </div>

      <div>
        <label>Avatar URL:</label>
        <input
          type="url"
          value={formData.avatar_url}
          onChange={(e) => setFormData({ ...formData, avatar_url: e.target.value })}
        />
      </div>

      <button type="submit" disabled={saving}>
        {saving ? 'Saving...' : 'Update Profile'}
      </button>
    </form>
  );
}
```

---

### Vue - Display Profile

```vue
<template>
  <div v-if="loading">Loading...</div>
  <div v-else-if="profile">
    <h1>My Profile</h1>
    <p>Email: {{ profile.email }}</p>
    <p>Name: {{ profile.full_name || 'Not set' }}</p>
    <p>Phone: {{ profile.phone || 'Not set' }}</p>
    <p>Role: {{ profile.role_slug }}</p>
    <img v-if="profile.avatar_url" :src="profile.avatar_url" alt="Avatar" />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { supabase } from './supabaseClient';

const profile = ref(null);
const loading = ref(true);

onMounted(async () => {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    const token = session?.access_token;

    const response = await fetch('http://localhost:8080/profile/me', {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    const data = await response.json();
    profile.value = data.profile;
  } catch (error) {
    console.error('Error fetching profile:', error);
  } finally {
    loading.value = false;
  }
});
</script>
```

---

## Security

### Row-Level Security (RLS)

The profiles table has RLS enabled with the following policies:

1. **Users can read own profile**
   ```sql
   CREATE POLICY "Users can read own profile"
     ON profiles FOR SELECT
     TO authenticated
     USING (auth.uid() = id);
   ```

2. **Users can update own profile**
   ```sql
   CREATE POLICY "Users can update own profile"
     ON profiles FOR UPDATE
     TO authenticated
     USING (auth.uid() = id)
     WITH CHECK (auth.uid() = id);
   ```

3. **Service role full access**
   ```sql
   CREATE POLICY "Service role full access to profiles"
     ON profiles FOR ALL
     TO service_role
     USING (true)
     WITH CHECK (true);
   ```

---

## Database Triggers

### 1. Auto-Create Profile on User Creation

```sql
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_profile_for_new_user();
```

**What it does:**
- Triggers when a new user is created in auth.users
- Automatically creates a profile with user's email and role

---

### 2. Sync Profile Role from Metadata

```sql
CREATE TRIGGER on_auth_user_metadata_updated
  AFTER UPDATE OF raw_user_meta_data ON auth.users
  FOR EACH ROW
  WHEN (OLD.raw_user_meta_data IS DISTINCT FROM NEW.raw_user_meta_data)
  EXECUTE FUNCTION sync_profile_role_from_metadata();
```

**What it does:**
- Triggers when user_metadata changes
- Syncs profile.role_slug with user_metadata.role

---

## Migration

### Apply the Migration

**Option 1: Supabase Dashboard**
1. Go to SQL Editor
2. Copy contents of `supabase/migrations/20250103000000_user_profiles.sql`
3. Run the SQL

**Option 2: Supabase CLI**
```bash
supabase db push
```

---

### Verify Migration

```sql
-- Check if profiles table exists
SELECT * FROM profiles LIMIT 5;

-- Check if triggers exist
SELECT * FROM pg_trigger
WHERE tgname IN ('on_auth_user_created', 'on_auth_user_metadata_updated');

-- Check if profiles were created for existing users
SELECT COUNT(*) FROM profiles;
SELECT COUNT(*) FROM auth.users;
-- These counts should match
```

---

## Troubleshooting

### Profile Not Created for User

**Check:**
```sql
-- Check if user exists
SELECT id, email FROM auth.users WHERE email = 'user@example.com';

-- Check if profile exists
SELECT * FROM profiles WHERE email = 'user@example.com';

-- Check if trigger exists
SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
```

**Fix:**
```sql
-- Manually create profile
INSERT INTO profiles (id, email, role_slug)
SELECT
  id,
  email,
  raw_user_meta_data->>'role'
FROM auth.users
WHERE email = 'user@example.com'
ON CONFLICT (id) DO NOTHING;
```

---

### Profile Role Not Syncing

**Check:**
```sql
-- Check user_metadata
SELECT id, email, raw_user_meta_data->>'role' as role
FROM auth.users
WHERE email = 'user@example.com';

-- Check profile role
SELECT id, email, role_slug
FROM profiles
WHERE email = 'user@example.com';

-- Check if trigger exists
SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_metadata_updated';
```

**Fix:**
```sql
-- Manually sync role
UPDATE profiles
SET role_slug = (
  SELECT raw_user_meta_data->>'role'
  FROM auth.users
  WHERE auth.users.id = profiles.id
)
WHERE id = 'user-uuid';
```

---

## Summary

✅ **Profiles table** stores additional user information
✅ **Auto-created** via database trigger when user signs up
✅ **Role syncing** keeps profile.role_slug in sync with user_metadata.role
✅ **Self-service endpoints** allow users to manage their own profile
✅ **Admin endpoints** allow admins to manage all profiles
✅ **Secure RLS** ensures users can only access their own profile
✅ **Pagination** for listing all profiles

For more information:
- [USER_METADATA_ROLES.md](./USER_METADATA_ROLES.md) - Role management
- [README.md](./README.md) - API documentation
- [STREAMLINED_WORKFLOW.md](./STREAMLINED_WORKFLOW.md) - Workflow examples
