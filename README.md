# dotfiles-ubuntu-24.04

Minhas configurações pessoais para Ubuntu 24.04 (Noble Numbat).  
Este repositório contém meus **dotfiles** (configurações do bash, zsh, vim, git, systemd, etc.) e um script de instalação para aplicar rapidamente em um novo ambiente.

---

## ✅ Pré-requisito de sistema

O único pré-requisito manual é o `git`, necessário para clonar este repositório
(o `setup.sh` cuida do resto — veja a seção abaixo):

```bash
sudo apt update && sudo apt install -y git
```

---

## 🚀 Como usar

Clone o repositório:

```bash
git clone https://github.com/belicio-cardoso/dotfiles-ubuntu-24.04.git ~/dotfiles-ubuntu-24.04
```

```bash
cd ~/dotfiles-ubuntu-24.04
```

```bash
chmod +x setup.sh
```

```bash
./setup.sh
```

O `setup.sh` cria **links simbólicos** do `$HOME` para os arquivos deste repositório.
Qualquer arquivo já existente no destino é preservado como `<arquivo>.backup`.

---

## 🔧 O que o `setup.sh` instala automaticamente

Antes de criar os symlinks, o script verifica e instala (pulando o que já
existir, então rodar de novo é seguro) tudo que `zsh/.zshrc` espera encontrar.
Os passos via `apt` pedem sua senha de `sudo` durante a execução.

| Dependência | Instalada via | Por quê |
| --- | --- | --- |
| `zsh` | `apt` | Shell alvo do `zsh/.zshrc` |
| Oh My Zsh (`~/.oh-my-zsh`) | instalador oficial (`RUNZSH=no CHSH=no KEEP_ZSHRC=yes`, não troca seu shell padrão nem abre sessão no meio do script) | `.zshrc` referencia `$ZSH="$HOME/.oh-my-zsh"` |
| `fzf`, `direnv` | `apt` | Plugin `fzf` e `eval "$(direnv hook zsh)"` do `.zshrc` |
| `zsh-syntax-highlighting`, `zsh-autosuggestions` | `git clone` em `~/.oh-my-zsh/custom/plugins/` | Listados em `plugins=(...)` no `.zshrc` |
| rustup/cargo (`~/.cargo/env`) | instalador oficial (`sh.rustup.rs`) | `.zshrc` faz `source $HOME/.cargo/env` |
| uv (`~/.local/bin/env`) | instalador oficial (`astral.sh/uv`) | `.zshrc` faz `. $HOME/.local/bin/env` |

---

## 📂 O que é versionado

| Caminho no repo | Destino no `$HOME` |
| --- | --- |
| `bash/.bashrc` | `~/.bashrc` |
| `zsh/.zshrc` | `~/.zshrc` |
| `git/.gitconfig` | `~/.gitconfig` |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `claude/RTK.md` | `~/.claude/RTK.md` |
| `claude/settings.json` | `~/.claude/settings.json` |
| `claude/skills/coolify/` | `~/.claude/skills/coolify/` |

---

## 📦 Dependências (instalar antes do `setup.sh`)

O `claude/settings.json` versionado referencia hooks em `~/.claude/hooks/`.
Esse diretório **não é versionado** — quem o cria são as ferramentas abaixo.
Instale-as em uma máquina nova, senão o Claude Code tentará executar hooks
que não existem:

| Ferramenta | Instalação | O que instala em `~/.claude/hooks/` |
| --- | --- | --- |
| GSD (`get-shit-done-cc`) | `npm i -g get-shit-done-cc` | `gsd-check-update.js`, `gsd-context-monitor.js`, `gsd-prompt-guard.js`, `gsd-statusline.js`, `gsd-workflow-guard.js` |
| RTK | ver instalador do projeto | `rtk-rewrite.sh`, `.rtk-hook.sha256` |

Ambas também reescrevem os blocos `hooks` e `statusLine` do `settings.json`
com caminhos absolutos. Se o `$HOME` da outra máquina tiver outro nome de
usuário, revise esses caminhos após instalar.

---

## ⚠️ Observações

- **Segredos nunca são versionados.** Veja o `.gitignore`: tokens, chaves, `.env`,
  histórico de shell e `~/.claude/settings.local.json` ficam de fora.
- **`~/.claude/hooks/` não é versionado.** Os arquivos pertencem ao GSD (npm) e ao
  RTK, que os reescrevem a cada atualização. Versioná-los criaria duas fontes de
  verdade para o mesmo arquivo: o repo sobreporia a versão instalada pelo npm, e o
  `gsd-check-update` — que compara a versão declarada dentro de cada hook com o
  `VERSION` local — acusaria "stale hooks" em máquinas com outra versão do GSD.
  Trate como `node_modules`: declare a dependência, não copie o código.
- **Agentes e comandos do Claude** (`~/.claude/agents/`, `~/.claude/commands/`,
  `~/.claude/plugins/`) **não** são versionados: são reinstalados pelos próprios plugins.
- `~/.zshrc` e `~/.gitconfig` contêm caminhos absolutos desta máquina
  (Google Cloud SDK, Android SDK, `gh`). Revise após clonar em um PC novo.
