-- ============================================================================
-- ReefBuddy Stripe Subscription Migration
-- Migration: 0003_add_stripe_subscription.sql
-- Author: @edge-engineer
-- Description: Adds Stripe customer and subscription fields to users table
--              for managing premium subscriptions.
-- ============================================================================

-- ============================================================================
-- USER TABLE UPDATES
-- Add Stripe customer ID and subscription ID for subscription management.
--
-- stripe_customer_id: Stripe customer identifier (cus_xxxxx)
--   - Created when user first subscribes
--   - Persists even after subscription cancellation
--   - Used for customer lookup and subscription management
--
-- stripe_subscription_id: Active Stripe subscription identifier (sub_xxxxx)
--   - Set when checkout.session.completed webhook fires
--   - Cleared when customer.subscription.deleted webhook fires
--   - Used to cancel or modify subscription
-- ============================================================================

ALTER TABLE users ADD COLUMN stripe_customer_id TEXT;
ALTER TABLE users ADD COLUMN stripe_subscription_id TEXT;

-- ============================================================================
-- INDEXES FOR SUBSCRIPTION QUERIES
-- Add indexes for efficient subscription lookups.
-- ============================================================================

-- Index for finding users by Stripe customer ID (webhook processing)
CREATE INDEX IF NOT EXISTS idx_users_stripe_customer ON users(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;

-- Index for finding users by Stripe subscription ID (webhook processing)
CREATE INDEX IF NOT EXISTS idx_users_stripe_subscription ON users(stripe_subscription_id) WHERE stripe_subscription_id IS NOT NULL;

-- Index for filtering premium users
CREATE INDEX IF NOT EXISTS idx_users_subscription_tier ON users(subscription_tier) WHERE deleted_at IS NULL;

-- ============================================================================
-- End of Stripe Subscription Migration
-- ============================================================================
