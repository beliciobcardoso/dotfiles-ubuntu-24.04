# dotfiles-ubuntu-24.04

Minhas configurações pessoais para Ubuntu 24.04 (Noble Numbat).  
Este repositório contém meus **dotfiles** (configurações do bash, zsh, vim, git, systemd, etc.) e um script de instalação para aplicar rapidamente em um novo ambiente.

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

## 📂 O que é versionado

| Caminho no repo | Destino no `$HOME` |
| --- | --- |
| `bash/.bashrc` | `~/.bashrc` |
| `zsh/.zshrc` | `~/.zshrc` |
| `git/.gitconfig` | `~/.gitconfig` |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `claude/RTK.md` | `~/.claude/RTK.md` |
| `claude/settings.json` | `~/.claude/settings.json` |
| `claude/hooks/` | `~/.claude/hooks/` |
| `claude/skills/coolify/` | `~/.claude/skills/coolify/` |

---

## ⚠️ Observações

- **Segredos nunca são versionados.** Veja o `.gitignore`: tokens, chaves, `.env`,
  histórico de shell e `~/.claude/settings.local.json` ficam de fora.
- **`claude/hooks/`** contém scripts instalados pelo plugin GSD e pelo RTK.
  São versionados porque `claude/settings.json` os referencia por caminho absoluto —
  sem eles, o Claude Code quebraria numa máquina nova. Ao atualizar GSD ou RTK,
  recopie os hooks para o repo.
- **Agentes e comandos do Claude** (`~/.claude/agents/`, `~/.claude/commands/`,
  `~/.claude/plugins/`) **não** são versionados: são reinstalados pelos próprios plugins.
- `~/.zshrc` e `~/.gitconfig` contêm caminhos absolutos desta máquina
  (Google Cloud SDK, Android SDK, `gh`). Revise após clonar em um PC novo.
