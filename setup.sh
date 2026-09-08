#!/usr/bin/env bash
set -e

echo "🚀 Iniciando configuração do ambiente Ubuntu 24.04..."

# Diretório base
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📋 Verificando git, zsh e Oh My Zsh..."

BASE_APT_PACKAGES=()
command -v git >/dev/null 2>&1 || BASE_APT_PACKAGES+=(git)
command -v zsh >/dev/null 2>&1 || BASE_APT_PACKAGES+=(zsh)

if [ ${#BASE_APT_PACKAGES[@]} -gt 0 ]; then
    echo "📦 Instalando via apt: ${BASE_APT_PACKAGES[*]}"
    sudo apt update && sudo apt install -y "${BASE_APT_PACKAGES[@]}"
else
    echo "✅ git e zsh já instalados"
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "✅ Oh My Zsh já instalado"
else
    echo "🎨 Instalando Oh My Zsh..."
    # RUNZSH=no e CHSH=no evitam que o instalador troque o shell padrão ou
    # abra uma sessão zsh no meio do setup.sh; KEEP_ZSHRC=yes evita que ele
    # sobrescreva um .zshrc existente (o setup.sh já cuida do symlink abaixo).
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

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
#
# ~/.claude/hooks/ NÃO entra aqui de propósito: seu conteúdo pertence ao npm
# (get-shit-done-cc) e ao RTK, que reescrevem os arquivos a cada atualização.
# Versioná-lo faria o repo sobrepor a versão instalada pelo gerenciador de
# pacotes — o gsd-check-update compara a versão declarada em cada hook com o
# VERSION local e acusaria "stale hooks" em máquinas com outra versão do GSD.
DIRS=(
    claude/skills/coolify:.claude/skills/coolify
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

echo ""
echo "📋 Instalando dependências do zsh/.zshrc (plugins, fzf, direnv, rustup, uv)..."

# Pacotes via apt usados diretamente pelo .zshrc (fzf plugin, direnv hook)
APT_PACKAGES=(fzf direnv)
MISSING_APT=()
for pkg in "${APT_PACKAGES[@]}"; do
    command -v "$pkg" >/dev/null 2>&1 || MISSING_APT+=("$pkg")
done

if [ ${#MISSING_APT[@]} -gt 0 ]; then
    echo "📦 Instalando via apt: ${MISSING_APT[*]}"
    sudo apt update && sudo apt install -y "${MISSING_APT[@]}"
else
    echo "✅ fzf e direnv já instalados"
fi

# Plugins do Oh My Zsh referenciados em plugins=(...) no .zshrc.
# Clonados em custom/plugins pois os pacotes apt não ficam onde o oh-my-zsh procura.
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ -d "$HOME/.oh-my-zsh" ]; then
    declare -A ZSH_PLUGIN_REPOS=(
        [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
        [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
    )
    for plugin in "${!ZSH_PLUGIN_REPOS[@]}"; do
        dest="$ZSH_CUSTOM/plugins/$plugin"
        if [ -d "$dest" ]; then
            echo "✅ Plugin $plugin já instalado"
        else
            echo "🔌 Clonando plugin $plugin..."
            git clone --depth=1 "${ZSH_PLUGIN_REPOS[$plugin]}" "$dest"
        fi
    done
else
    echo "⏭  ~/.oh-my-zsh não encontrado — pulando plugins do zsh (instale o Oh My Zsh antes)"
fi

# rustup/cargo — o .zshrc faz "source $HOME/.cargo/env"
if [ -f "$HOME/.cargo/env" ]; then
    echo "✅ rustup/cargo já instalado"
else
    echo "🦀 Instalando rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# uv — o .zshrc faz ". $HOME/.local/bin/env"
if [ -f "$HOME/.local/bin/env" ]; then
    echo "✅ uv já instalado"
else
    echo "🐍 Instalando uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

echo "✅ Configuração concluída!"
