# Declarative database schemas

The SQL files in this directory are the source of truth for the final state of
the `public` database schema. Files are evaluated in lexicographic order.

To change the database:

1. Edit the relevant file in this directory.
2. Generate a migration from `server/` with `supabase db diff -f <name>`.
3. Review the generated migration before applying it.
4. Apply locally with `supabase migration up`, then deploy it.

Keep data operations that schema diffing cannot represent, such as inserting
rows into `storage.buckets`, in a handwritten migration.
