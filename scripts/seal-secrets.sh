#!/bin/bash
set -euo pipefail

MANIFESTS_DIR="$(cd "$(dirname "$0")/../manifests/infra" && pwd)"

if ! command -v kubeseal >/dev/null 2>&1; then
    echo "Error: kubeseal is not installed."
    echo "Install it: https://github.com/bitnami-labs/sealed-secrets#installation"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is not installed."
    exit 1
fi

echo "Generating secrets for Questify microservices..."
echo "Output directory: $MANIFESTS_DIR"

# ─── Generate credentials ────────────────────────────────────────────────────

JWT_SECRET="$(openssl rand -hex 32)"

RABBITMQ_USER="questify"
RABBITMQ_PASSWORD="$(openssl rand -hex 24)"

GARAGE_ACCESS_KEY_ID="GK$(openssl rand -hex 12)"
GARAGE_SECRET_ACCESS_KEY="$(openssl rand -hex 32)"

AUTH_DB_USER="questify"
AUTH_DB_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -hex 24)}"

QUEST_DB_USER="quest_svc"
QUEST_DB_PASSWORD="$(openssl rand -hex 16)"

PROJECT_DB_USER="project_svc"
PROJECT_DB_PASSWORD="$(openssl rand -hex 16)"

PROGRESSION_DB_USER="progression_svc"
PROGRESSION_DB_PASSWORD="$(openssl rand -hex 16)"

STATS_DB_USER="stats_svc"
STATS_DB_PASSWORD="$(openssl rand -hex 16)"

ADMIN_DB_USER="admin_svc"
ADMIN_DB_PASSWORD="$(openssl rand -hex 16)"

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@questify.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 16)}"

seal() {
    local name="$1"
    local namespace="${2:-questify}"
    kubectl create secret generic "$name" \
        --namespace "$namespace" \
        --dry-run=client \
        -o yaml \
        "${@:3}" \
        | kubeseal --format yaml
}

echo ""
echo "Sealing JWT secrets..."
{
    seal questify-auth-jwt questify \
        --from-literal=jwt-secret="$JWT_SECRET"
    echo "---"
    seal questify-admin-jwt questify \
        --from-literal=jwt-secret="$JWT_SECRET"
} > "$MANIFESTS_DIR/sealed-jwt.yaml"
echo "  -> $MANIFESTS_DIR/sealed-jwt.yaml"

echo "Sealing Garage S3 secret..."
seal questify-garage questify \
    --from-literal=access-key="$GARAGE_ACCESS_KEY_ID" \
    --from-literal=secret-key="$GARAGE_SECRET_ACCESS_KEY" \
    > "$MANIFESTS_DIR/sealed-garage.yaml"
echo "  -> $MANIFESTS_DIR/sealed-garage.yaml"

echo "Sealing RabbitMQ secret..."
seal questify-rabbitmq questify \
    --from-literal=username="$RABBITMQ_USER" \
    --from-literal=password="$RABBITMQ_PASSWORD" \
    > "$MANIFESTS_DIR/sealed-rabbitmq.yaml"
echo "  -> $MANIFESTS_DIR/sealed-rabbitmq.yaml"

echo "Sealing admin bootstrap secret..."
seal questify-auth-admin questify \
    --from-literal=admin-email="$ADMIN_EMAIL" \
    --from-literal=admin-password="$ADMIN_PASSWORD" \
    > "$MANIFESTS_DIR/sealed-auth-admin.yaml"
echo "  -> $MANIFESTS_DIR/sealed-auth-admin.yaml"

echo "Sealing service database secrets..."
{
    seal questify-auth-db questify \
        --from-literal=username="$AUTH_DB_USER" \
        --from-literal=password="$AUTH_DB_PASSWORD"
    echo "---"
    seal questify-quest-db questify \
        --from-literal=username="$QUEST_DB_USER" \
        --from-literal=password="$QUEST_DB_PASSWORD"
    echo "---"
    seal questify-project-db questify \
        --from-literal=username="$PROJECT_DB_USER" \
        --from-literal=password="$PROJECT_DB_PASSWORD"
    echo "---"
    seal questify-progression-db questify \
        --from-literal=username="$PROGRESSION_DB_USER" \
        --from-literal=password="$PROGRESSION_DB_PASSWORD"
    echo "---"
    seal questify-stats-db questify \
        --from-literal=username="$STATS_DB_USER" \
        --from-literal=password="$STATS_DB_PASSWORD"
    echo "---"
    seal questify-admin-db questify \
        --from-literal=username="$ADMIN_DB_USER" \
        --from-literal=password="$ADMIN_DB_PASSWORD"
} > "$MANIFESTS_DIR/sealed-services-db.yaml"
echo "  -> $MANIFESTS_DIR/sealed-services-db.yaml"

echo "Sealing PostgreSQL init secret (service users)..."
INIT_SCRIPT="$(cat <<EOF
#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE SCHEMA IF NOT EXISTS auth;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE USER $QUEST_DB_USER WITH PASSWORD '$QUEST_DB_PASSWORD';" || true
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE SCHEMA IF NOT EXISTS quest;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON SCHEMA quest TO $QUEST_DB_USER;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE USER $PROJECT_DB_USER WITH PASSWORD '$PROJECT_DB_PASSWORD';" || true
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE SCHEMA IF NOT EXISTS project;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON SCHEMA project TO $PROJECT_DB_USER;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE USER $PROGRESSION_DB_USER WITH PASSWORD '$PROGRESSION_DB_PASSWORD';" || true
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE SCHEMA IF NOT EXISTS progression;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON SCHEMA progression TO $PROGRESSION_DB_USER;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE USER $STATS_DB_USER WITH PASSWORD '$STATS_DB_PASSWORD';" || true
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE SCHEMA IF NOT EXISTS stats;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON SCHEMA stats TO $STATS_DB_USER;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE USER $ADMIN_DB_USER WITH PASSWORD '$ADMIN_DB_PASSWORD';" || true
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "CREATE SCHEMA IF NOT EXISTS admin;"
psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON SCHEMA admin TO $ADMIN_DB_USER;"
EOF
)"

kubectl create secret generic questify-db-init \
    --namespace questify \
    --dry-run=client \
    -o yaml \
    --from-literal=init.sh="$INIT_SCRIPT" \
    | kubeseal --format yaml \
    > "$MANIFESTS_DIR/sealed-db-init.yaml"
echo "  -> $MANIFESTS_DIR/sealed-db-init.yaml"

echo ""
echo "========================================================"
echo "  All secrets sealed successfully!"
echo "========================================================"
echo ""
echo "  SAVE THESE CREDENTIALS:"
echo "  Admin email:    $ADMIN_EMAIL"
echo "  Admin password: $ADMIN_PASSWORD"
echo "  JWT secret:     $JWT_SECRET"
echo "  Garage key ID:  $GARAGE_ACCESS_KEY_ID"
echo "  RabbitMQ pass:  $RABBITMQ_PASSWORD"
echo ""
echo "  Commit the generated files in manifests/infra/"
echo "========================================================"
