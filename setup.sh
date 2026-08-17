#!/usr/bin/env bash
set -e

echo "🚀 Iniciando configuração do ambiente Ubuntu 24.04..."

# Diretório base
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Lista de arquivos para link simbólico
FILES=(bash/.bashrc zsh/.zshrc vim/.vimrc git/.gitconfig)

for file in "${FILES[@]}"; do
    src="$DOTFILES_DIR/$file"
    dest="$HOME/$(basename $file)"
    
    if [ -f "$dest" ] || [ -L "$dest" ]; then
        echo "📦 Backup de $dest para $dest.backup"
        mv "$dest" "$dest.backup"
    fi

    echo "🔗 Criando link simbólico: $dest -> $src"
    ln -s "$src" "$dest"
done

# Diretórios para link simbólico, no formato "origem:destino-relativo-ao-HOME".
# Necessário porque o destino não fica na raiz do $HOME (ao contrário de FILES).
DIRS=(claude/skills/coolify:.claude/skills/coolify)

for entry in "${DIRS[@]}"; do
    src="$DOTFILES_DIR/${entry%%:*}"
    dest="$HOME/${entry##*:}"

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
