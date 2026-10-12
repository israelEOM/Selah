-- Nobody changes a role through the API; roles are set with the service role.
-- A column-level revoke has no effect while the table-level grant exists, so the
-- table grant is replaced by a grant on the one editable column.
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (name) on public.profiles to authenticated;
