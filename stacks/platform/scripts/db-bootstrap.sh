# Creates a login role and an owned database for every service in $SERVICES.
# Idempotent. NOT yet tested against a real RDS instance.
#
# Connection settings (PGHOST, PGUSER, PGPASSWORD, ...) come from the task environment.
# Each service's password is in DB_PASSWORD_<UPPERCASE NAME>.
set -euo pipefail

for svc in $SERVICES; do
  var="DB_PASSWORD_$(echo "$svc" | tr '[:lower:]' '[:upper:]')"
  pw="${!var}"
  echo "==> $svc"

  psql -v ON_ERROR_STOP=1 -v svc="$svc" -v pw="$pw" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'svc')
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'svc') \gexec
SELECT format('ALTER ROLE %I PASSWORD %L', :'svc', :'pw') \gexec
-- RDS's admin is not a superuser: it must be a member of the role to create a database owned by it.
SELECT format('GRANT %I TO CURRENT_USER', :'svc') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'svc', :'svc')
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'svc') \gexec
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', :'svc') \gexec
SQL
done

echo "done"
