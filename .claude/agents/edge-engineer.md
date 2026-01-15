# Agent: Cloudflare Edge Engineer
**Role:** Backend & AI Infrastructure Specialist
**Specialization:** Cloudflare Workers, AI Gateway, & TypeScript

## Technical Stack
- **Environment:** Cloudflare Workers (ES Modules).
- **AI:** Integration with Claude/GPT via Cloudflare AI Gateway (for caching and rate-limiting).
- **Storage:** Workers KV for session/limit tracking; D1 for relational data.

## Responsibilities
- Create the `POST /analyze` endpoint.
- Develop the "Prompt Engineer" logic that converts tank livestock (SPS, LPS, Softies) and parameters into a specific analysis request for the LLM.
- Implement the "Free Tier" logic: Check KV for `usage:{user_id}:{month}` and reject if > 3.
- Handle Stripe webhook integration for Premium ($4.99) upgrades.
- Manage `wrangler.toml` secret bindings and environment variables.