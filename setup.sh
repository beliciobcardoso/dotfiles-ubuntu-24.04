#!/usr/bin/env bash
set -e

echo "🚀 Iniciando configuração do ambiente Ubuntu 24.04..."

# Diretório base
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Arquivos linkados na raiz do $HOME (o destino é sempre $HOME/<basename>)
FILES=(bash/.bashrc zsh/.zshrc vim/.vimrc git/.gitconfig)

for file in "${FILES[@]}"; do
    src="$DOTFILES_DIR/$file"
    dest="$HOME/$(basename $file)"

    # Sem isso, um item de FILES que não existe no repo geraria um symlink quebrado
    # e ainda renomearia o arquivo bom do $HOME para .backup.
    if [ ! -e "$src" ]; then
        echo "⏭  Ignorado (ausente no repo): $file"
        continue
    fi

    if [ -f "$dest" ] || [ -L "$dest" ]; then
        echo "📦 Backup de $dest para $dest.backup"
        mv "$dest" "$dest.backup"
    fi

    echo "🔗 Criando link simbólico: $dest -> $src"
    ln -s "$src" "$dest"
done

# Arquivos cujo destino NÃO fica na raiz do $HOME, no formato
# "origem-relativa-ao-repo:destino-relativo-ao-HOME".
NESTED_FILES=(
    claude/CLAUDE.md:.claude/CLAUDE.md
    claude/RTK.md:.claude/RTK.md
    claude/settings.json:.claude/settings.json
)

for entry in "${NESTED_FILES[@]}"; do
    src="$DOTFILES_DIR/${entry%%:*}"
    dest="$HOME/${entry##*:}"

    if [ ! -e "$src" ]; then
        echo "⏭  Ignorado (ausente no repo): ${entry%%:*}"
        continue
    fi

    mkdir -p "$(dirname "$dest")"

    if [ -f "$dest" ] || [ -L "$dest" ]; then
        echo "📦 Backup de $dest para $dest.backup"
        mv "$dest" "$dest.backup"
    fi

    echo "🔗 Criando link simbólico: $dest -> $src"
    ln -s "$src" "$dest"
done

# Diretórios para link simbólico, no formato "origem:destino-relativo-ao-HOME".
# Necessário porque o destino não fica na raiz do $HOME (ao contrário de FILES).
DIRS=(
    claude/skills/coolify:.claude/skills/coolify
    claude/hooks:.claude/hooks
)

for entry in "${DIRS[@]}"; do
    src="$DOTFILES_DIR/${entry%%:*}"
    dest="$HOME/${entry##*:}"

    if [ ! -e "$src" ]; then
        echo "⏭  Ignorado (ausente no repo): ${entry%%:*}"
        continue
    fi

    mkdir -p "$(dirname "$dest")"

    if [ -L "$dest" ]; then
        rm "$dest"
    elif [ -d "$dest" ]; then
        echo "📦 Backup de $dest para $dest.backup"
        mv "$dest" "$dest.backup"
    fi

    echo "🔗 Criando link simbólico: $dest -> $src"
    ln -s "$src" "$dest"
done

echo "✅ Configuração concluída!"
