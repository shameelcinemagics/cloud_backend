#!/bin/bash

# ============================================================================
# Deployment Script for Database Migrations
# ============================================================================

set -e  # Exit on error

echo "============================================================================"
echo "🚀 Database Migration Deployment Script"
echo "============================================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI not found!${NC}"
    echo "Install it with: npm install -g supabase"
    exit 1
fi

echo -e "${GREEN}✅ Supabase CLI found${NC}"
echo ""

# Check current directory
if [ ! -d "supabase/migrations" ]; then
    echo -e "${RED}❌ Not in the correct directory!${NC}"
    echo "Please run this script from: /Users/misbahak/Desktop/mak/kwt/gcp/Cloud_backend/cloud_backend"
    exit 1
fi

echo -e "${GREEN}✅ Found migrations directory${NC}"
echo ""

# List pending migrations
echo "============================================================================"
echo "📋 Pending Migrations:"
echo "============================================================================"
echo ""
echo "  1. 20251208114450_new-migration.sql"
echo "     → Production optimization (indexes, views, functions, cleanup)"
echo ""
echo "  2. 20251208125014_sync_prod_dev_schemas.sql"
echo "     → Sync prod/dev schemas (vending machines, products, sales)"
echo ""

# Prompt for confirmation
read -p "Do you want to proceed with migration? (y/N): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    echo -e "${YELLOW}⚠️  Migration cancelled${NC}"
    exit 0
fi

echo ""
echo "============================================================================"
echo "🔍 Pre-flight Checks"
echo "============================================================================"
echo ""

# Check Supabase status
echo "Checking Supabase connection..."
supabase status || {
    echo -e "${YELLOW}⚠️  Not connected to a Supabase project${NC}"
    echo ""
    read -p "Enter your Supabase project ref: " project_ref
    echo "Linking to project..."
    supabase link --project-ref "$project_ref" || exit 1
}

echo -e "${GREEN}✅ Connected to Supabase${NC}"
echo ""

# Backup reminder
echo "============================================================================"
echo "💾 Backup Reminder"
echo "============================================================================"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Make sure you have a recent backup!${NC}"
echo ""
read -p "Do you have a recent backup? (y/N): " backup_confirm
if [[ $backup_confirm != [yY] && $backup_confirm != [yY][eE][sS] ]]; then
    echo -e "${RED}❌ Please create a backup first!${NC}"
    echo "You can create a backup from the Supabase Dashboard:"
    echo "  → Database → Backups"
    exit 1
fi

echo ""
echo "============================================================================"
echo "🚀 Pushing Migrations..."
echo "============================================================================"
echo ""

# Push migrations
supabase db push

echo ""
echo "============================================================================"
echo "✅ Migration Complete!"
echo "============================================================================"
echo ""

# Post-deployment verification
echo "============================================================================"
echo "🔍 Running Verification..."
echo "============================================================================"
echo ""

echo "Would you like to run verification queries? (y/N): "
read -p "" verify_confirm
if [[ $verify_confirm == [yY] || $verify_confirm == [yY][eE][sS] ]]; then
    echo ""
    echo "You can verify the deployment by running:"
    echo ""
    echo "  supabase db pull --schema public"
    echo ""
    echo "Or run the verification script:"
    echo ""
    echo "  psql [your-connection-string] < verify-deployment.sql"
    echo ""
fi

echo ""
echo "============================================================================"
echo "📚 Next Steps"
echo "============================================================================"
echo ""
echo "1. ✅ Verify all tables exist"
echo "2. ✅ Test the new views:"
echo "      SELECT * FROM public.machine_inventory_status LIMIT 5;"
echo "      SELECT * FROM public.low_stock_items LIMIT 5;"
echo "      SELECT * FROM public.low_stock_slots LIMIT 5;"
echo ""
echo "3. ✅ Update TypeScript types (if using frontend):"
echo "      npx supabase gen types typescript > src/integrations/supabase/types.ts"
echo ""
echo "4. ✅ Run VACUUM ANALYZE for optimization:"
echo "      VACUUM ANALYZE public.warehouse_stock;"
echo "      VACUUM ANALYZE public.products;"
echo "      VACUUM ANALYZE public.vending_machines;"
echo ""
echo "5. ✅ Review documentation:"
echo "      cat SCHEMA_SYNC_SUMMARY.md"
echo "      cat DATABASE_FEATURES.md"
echo ""
echo "============================================================================"
echo "🎉 Deployment Complete!"
echo "============================================================================"
echo ""
