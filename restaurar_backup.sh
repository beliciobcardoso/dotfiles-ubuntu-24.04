#!/bin/bash

# --- CONFIGURAÇÕES ---
CONTAINER_NAME="postgis_container"
DUMP_FILE_PATH="/media/bello/Backup/BACKUPS/itower_NovaCorrente_backup_20250919_151019.dump"
DB_NAME="itower_NovaCorrente"
POSTGRES_USER="postgres"

# --- FIM DAS CONFIGURAÇÕES ---

# --- FUNÇÃO DE ANIMAÇÃO ---
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep "$pid")" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "    \r"
}

# --- FUNÇÃO DE LIMPEZA (GARANTE QUE O SPINNER PARE) ---
cleanup() {
    tput cnorm # Garante que o cursor volte ao normal
    if [ ! -z "$spinner_pid" ]; then
        kill $spinner_pid 2>/dev/null
    fi
}

# Trap para chamar a função cleanup em caso de interrupção (Ctrl+C)
trap cleanup EXIT

# Checagem inicial
if [ ! -f "$DUMP_FILE_PATH" ]; then
    echo "Erro: O arquivo de backup não foi encontrado em '$DUMP_FILE_PATH'"
    exit 1
fi

echo "--- Iniciando o processo de restauração ---"

# Passo 1: Forçar o encerramento de conexões
echo "1/5: Terminando conexões ativas com o banco '$DB_NAME'..."
docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" > /dev/null
echo "Conexões encerradas."
echo ""

# Passo 2: Apagar o banco de dados antigo
echo "2/5: Apagando o banco de dados '$DB_NAME' (se existir)..."
docker exec "$CONTAINER_NAME" dropdb -U "$POSTGRES_USER" "$DB_NAME" --if-exists
echo "Banco de dados antigo removido (ou não existia)."
echo ""

# Passo 3: Criar um novo banco de dados
echo "3/5: Criando o banco de dados '$DB_NAME'..."
docker exec "$CONTAINER_NAME" createdb -U "$POSTGRES_USER" "$DB_NAME"
if [ $? -ne 0 ]; then echo "Erro: Falha ao criar o banco de dados."; exit 1; fi
echo "Banco de dados criado com sucesso!"
echo ""

# Passo 4: Criar as roles e atribuir permissões
echo "4.1/5: Criando o role 'admin'..."
docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$DB_NAME" -c "CREATE ROLE admin;" > /dev/null
if [ $? -ne 0 ]; then echo "Aviso: Role 'admin' pode já existir."; else echo "Role 'admin' criado com sucesso!"; fi
echo ""

echo "4.2/5: Criando o role 'pb'..."
docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$DB_NAME" -c "CREATE ROLE pb;" > /dev/null
if [ $? -ne 0 ]; then echo "Aviso: Role 'pb' pode já existir."; else echo "Role 'pb' criado com sucesso!"; fi
echo ""

echo "4.3/5: Criando o role 'n8n'..."
docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$DB_NAME" -c "CREATE ROLE n8n;" > /dev/null
if [ $? -ne 0 ]; then echo "Aviso: Role 'n8n' pode já existir."; else echo "Role 'n8n' criado com sucesso!"; fi
echo ""

# Passo 5: Restaurar o backup
echo "5/5: Restaurando o backup de '$DUMP_FILE_PATH'..."

# Inicia o cronômetro
start_time=$(date +%s)

# Esconde o cursor para a animação ficar mais limpa
tput civis

# Executa a restauração em si, e a animação em background
(cat "$DUMP_FILE_PATH" | docker exec -i "$CONTAINER_NAME" pg_restore -U "$POSTGRES_USER" -d "$DB_NAME") &
restore_pid=$!
spinner $restore_pid &
spinner_pid=$!

# Espera o processo de restauração terminar
wait $restore_pid
restore_exit_code=$?

# Para a animação e mostra o cursor novamente
kill $spinner_pid
tput cnorm

# Para o cronômetro
end_time=$(date +%s)

# Calcula o tempo total
duration=$((end_time - start_time))
minutes=$((duration / 60))
seconds=$((duration % 60))

if [ $restore_exit_code -ne 0 ]; then
    echo ""
    echo "Erro: Falha durante a restauração com pg_restore."
    exit 1
fi

echo ""
echo "Restauração concluída."
echo ""
echo "--- Processo concluído! ---"
echo "O backup foi restaurado com sucesso no banco de dados '$DB_NAME'."
echo "Tempo total da restauração: ${minutes} minutos e ${seconds} segundos."