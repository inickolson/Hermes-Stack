# Резервное копирование excess-salmon → домашний MacBook

Ручной (по кнопке) инкрементальный бэкап сервера на внешний HDD `Home` (250 GB, монтируется в `/Volumes/Home` на Mac).

## Что бэкапится

| Цель | Откуда | Что внутри | Примерный объём |
|---|---|---|---|
| `stack/` | `/opt/hermes-stack/` | git, compose, env, скрипты, docs | ~2.2 GB |
| `data/` | `/opt/data/` | профили агентов, сессии, навыки, `auth.json` | ~3.2 GB |
| `rag/` | `/root/open-notebook/surreal_data/` | RAG-база SurrealDB Open Notebook | 1–3 GB |

**Исключения:**

- `stack/`: `data/`, `*.log`, временные pack-файлы git
- `data/`: `.cache/`, `patchright-browsers/`, `logs/`, `.npm/_logs/`, `audio_cache/`, `image_cache/`, `__pycache__/`

**Первый бэкап:** ~6–8 GB (все три цели целиком).
**Последующие:** ~50–500 MB в день (только дельта; неизменённые файлы — hardlink на предыдущую копию).

## Куда складывается

На Mac:
```
/Volumes/Home/Backups/hermes/<YYYY-MM-DD>/
    stack/
    data/
    rag/
```

Хранится **7 последних копий** (≈ 1 неделя). Старше — удаляется автоматически после каждого бэкапа.

## Что в комплекте (workspace воркера)

- `backup-to-mac.sh` — основной скрипт
- `rotate-mac-backups.sh` — ротация (вызывается из основного)
- `backup-to-mac.md` — эта документация
- `install-on-server.sh` — одноразовая раскладка на сервер
- `mac_backup_key` + `mac_backup_key.pub` — пара ed25519, **уже сгенерирована** в воркере.
  Пароль не задан. При запуске `install-on-server.sh` оба файла раскладываются в
  `/root/.ssh/` (600/644). Если ключ уже есть — установщик **не перезапишет**.

> **Если хочется перегенерить пару** (рекомендуется для свежего деплоя):
> ```bash
> ssh-keygen -t ed25519 -f /root/.ssh/mac_backup_key -N '' -C 'excess-salmon → Mac backup'
> cat /root/.ssh/mac_backup_key.pub
> ```
> …и использовать выведенную строку на шаге 2.

## Одноразовая настройка

### 1. (Автоматически) SSH-ключ лежит в комплекте

Если пара `mac_backup_key` / `mac_backup_key.pub` уже лежит в комплекте,
`install-on-server.sh` сам разложит её в `/root/.ssh/`. Можно ничего не делать —
только перейти к шагу 2.

### 1. (Вручную) Сгенерировать SSH-ключ на СЕРВЕРЕ

Если хочется генерить ключ **на самом сервере** (root):

```bash
ssh-keygen -t ed25519 -f /root/.ssh/mac_backup_key -N '' -C 'excess-salmon → Mac backup'
cat /root/.ssh/mac_backup_key.pub
```

Скопировать выведенную строку (начинается с `ssh-ed25519 AAAA…`).

### 2. Добавить ключ на Mac

На **MacBook**, в терминале (zsh):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
echo "ssh-ed25519 AAAA…вставь_сюда_публичный_ключ… excess-salmon → Mac backup" >> ~/.ssh/authorized_keys
```

Включить Remote Login: Системные настройки → Общий доступ → Удалённый вход → ВКЛ.
Опционально разрешить вход root: в том же окне "Разрешить удалённый вход для: всем пользователям" или точечно для своего юзера (под ним запустится rsync).

> **Безопасность:** ключ `mac_backup_key` не имеет passphrase, но имеет жёсткий `--from` ограничитель (см. шаг 3). Держите файл `/root/.ssh/mac_backup_key` в режиме `600`, владелец `root:root`.

### 3. (Опционально) Ограничить ключ на Mac — только rsync, только нужный путь

Чтобы даже при утечке ключа злоумышленник не мог делать `ssh mac 'rm -rf /'`, перед строкой ключа в `~/.ssh/authorized_keys` на Mac добавьте ограничители:

```
from="89.22.234.108",command="/bin/true",no-pty,no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAA… excess-salmon → Mac backup
```

(`command="/bin/true"` — запрет произвольных команд; для rsync-через-ssh это **не помешает**, потому что rsync сам поднимает свой ssh-канал и команда `rsync --server …` на стороне Mac легитимна. Если строгий запрет команд мешает rsync, оставьте `from=` + `no-pty` + `no-port-forwarding`.)

### 4. Узнать имя хоста / IP Mac в локальной сети

На Mac: Системные настройки → Сеть → IP-адрес (например, `192.168.1.42`), либо `hostname` в zsh. С сервера проверьте:

```bash
ssh -i /root/.ssh/mac_backup_key -p 22 -o BatchMode=yes -o ConnectTimeout=5 igor@<IP-или-hostname> 'echo ok && df -h /Volumes/Home'
```

Если Mac в той же LAN, обычно хватает `<MAC_HOST>=mac.local` или `<MAC_HOST>=<IP>`.

### 5. Положить скрипты на сервер

См. `install-on-server.sh` в комплекте задачи — он копирует `backup-to-mac.sh` и `rotate-mac-backups.sh` в `/opt/hermes-stack/scripts/` и делает `chmod +x`.

## Запуск бэкапа

**Перед снятием образа** (вручную, по кнопке):

```bash
bash /opt/hermes-stack/scripts/backup-to-mac.sh
```

Время выполнения: 5–30 минут в зависимости от дельты и пропускной способности LAN.
Прогресс пишется в `/var/log/hermes-backup-mac.log` (на сервере).

> **Важно:** НЕ через cron. Mac выключается — крон просто будет спамить ошибками в лог.

## Переменные окружения (опционально)

Перед запуском можно переопределить:

```bash
export HERMES_BACKUP_MAC_USER=igor
export HERMES_BACKUP_MAC_HOST=192.168.1.42     # или mac.local
export HERMES_BACKUP_MAC_DEST=/Volumes/Home/Backups/hermes
export HERMES_BACKUP_SSH_PORT=22
export HERMES_BACKUP_SSH_KEY=/root/.ssh/mac_backup_key
bash /opt/hermes-stack/scripts/backup-to-mac.sh
```

## Как восстановиться

### Стек (`stack/`)

```bash
# на свежем сервере:
rsync -a /Volumes/Home/Backups/hermes/2026-09-04/stack/ /opt/hermes-stack/
cd /opt/hermes-stack && docker compose up -d
```

### Данные агентов (`data/`)

```bash
rsync -a /Volumes/Home/Backups/hermes/2026-09-04/data/ /opt/data/
# перезапустить hermes, чтобы он подхватил auth.json и навыки
docker restart hermes-v20
```

### RAG SurrealDB (`rag/`)

```bash
# стопнуть Open Notebook
docker stop open-notebook
# очистить текущую (пустую/битую) базу
rm -rf /root/open-notebook/surreal_data
# восстановить
rsync -a /Volumes/Home/Backups/hermes/2026-09-04/rag/ /root/open-notebook/surreal_data/
chown -R 0:0 /root/open-notebook/surreal_data    # root-owned, иначе crashloop
# поднять обратно
docker start open-notebook
```

## Если что-то отвалилось

| Симптом | Что делать |
|---|---|
| `ssh: Could not resolve hostname mac.local` | Проверь `hostname` на Mac, либо используй IP-адрес. Сделай `export HERMES_BACKUP_MAC_HOST=192.168.x.x`. |
| `Permission denied (publickey)` | Ключ не добавлен в `~/.ssh/authorized_keys` на Mac, или права на файлы неверные (на Mac: `chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys`). |
| `read-only file system` / `No space left on device` | Проверь `df -h /Volumes/Home` на Mac. Либо уменьши `KEEP_DAYS` в `rotate-mac-backups.sh`. |
| `rsync: connection unexpectedly closed` | Mac ушёл в сон. Открой Системные настройки → Экономия энергии → "Запретить автоматический переход в сон при подключении к источнику питания", либо запускай бэкап при бодрствующем Mac. |
| `WARN: копия за YYYY-MM-DD уже существует` | Сегодня уже бэкапили — это защита от дубля. Удали вручную: `ssh mac 'rm -rf /Volumes/Home/Backups/hermes/YYYY-MM-DD'` и перезапусти. |
| `не могу создать /var/log/hermes-backup-mac.log` | Запускай от root: `sudo bash /opt/hermes-stack/scripts/backup-to-mac.sh`. |

## Куда смотреть

- Лог бэкапа: `/var/log/hermes-backup-mac.log` (на **сервере**)
- Содержимое бэкапа: `ls -la /Volumes/Home/Backups/hermes/<YYYY-MM-DD>/` (на **Mac**)
- Объём: `du -sh /Volumes/Home/Backups/hermes/<YYYY-MM-DD>/*` (на **Mac**)
