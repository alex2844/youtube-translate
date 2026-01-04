# YouTube Translate

> Translate and download videos effortlessly, bypassing throttling.

This script allows you to easily translate videos from YouTube and other online
platforms. It uses [`vot-cli`](https://github.com/FOSWLY/vot-cli) for
translation and other command-line utilities like [`ffmpeg`](https://ffmpeg.org/)
and [`yt-dlp`](https://github.com/yt-dlp/yt-dlp).

The script is designed to be fast and flexible. Running it in **Google Colab**
allows you to download videos at high speed, bypassing ISP throttling.

It creates universally compatible files (MKV + MP3/AVC) that work smoothly
on Chromecast, Android TV, and Chrome OS.

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)][notebook]

## Features

* **Bypass Throttling**: Use the Google Colab version to download videos
  from YouTube via Google's servers, avoiding ISP speed limits.
* **Simple Downloader**: Just set the source and target languages to be the
  same (e.g., `en` to `en`) to use the script as a powerful video downloader.
* **Automatic Translation**: Translate videos from YouTube and other sources.
* **SponsorBlock Integration**: Marks sponsor segments as chapters for automatic
  skipping in players like Kodi and VLC (enabled by default).
* **Media Center Integration**: Automatically generates `.nfo` metadata and
  thumbnail files, perfect for Kodi, Jellyfin, and Emby.
* **High performance**: Optimized for speed using the MKV container and MP3 audio,
  avoiding heavy transcoding.
* **Playlist support**: Process entire YouTube playlists automatically.
* **YouTube Sync**: Mark videos as "watched" on YouTube (requires cookies).
* **Local file support**: Use an existing video file to save bandwidth, while
  fetching the translation using the URL.
* **Configuration**: Support for `.env` files, settings saving (Colab), and
  flexible flags.

## Usage

### Local

1. Install the necessary dependencies (ffmpeg, yt-dlp, vot-cli, npm/pip).
2. Make [`ytranslate.sh`][script]  executable: `chmod +x ytranslate.sh`.
3. (Optional) Create a `.env` file to store your preferences (e.g.,
   `YT_TOLANG=ru`).
4. Run the script:

    ```bash
    ./ytranslate.sh [OPTIONS] <URL> [LOCAL_FILE]
    ```

    **Options:**

    * `-h, --help`: Show help message.
    * `-v, --version`: Show script version.
    * `-r, --height=<int>`: Set max video height (e.g., 1080).
    * `-f, --from_lang=<str>`: Source language (default: en).
    * `-t, --to_lang=<str>`: Target language (default: ru).
    * `-o, --output=<path>`: Output directory.
    * `-c, --cookies=<path>`: Path to cookies file (for private playlists or
      marking watched).
    * `-4, --ipv4`: Force IPv4 connection.
    * `--force-avc`: Force AVC (H.264) video codec for older devices.
    * `--mark-watched`: Mark video as watched on YouTube (requires cookies).
    * `--meta`: Generate NFO and JPG for Media Centers.
    * `--no-sponsorblock`: Disable marking sponsor segments (enabled by default).
    * `--no-cleanup`: Keep temporary files.

    **Examples:**

    Translate a single video with metadata:

    ```bash
    ./ytranslate.sh -f en -t ru --meta https://youtu.be/VIDEO_ID
    ```

    Download a playlist in its original language, creating metadata and marking
    as watched:

    ```bash
    ./ytranslate.sh -f en -t en -c cookies.txt --meta --mark-watched \
      https://www.youtube.com/playlist?list=WL
    ```

### Google Colab (Bypass Throttling)

1. Open the [`ytranslate.ipynb`][notebook] file in Google Colab.
2. Fill in the parameters in the "Settings" block.
3. **To simply download**, set `FROMLANG` and `TOLANG` to the same language.
4. Run all cells.
5. The script will process the video(s) and automatically save them to your
   Google Drive or prompt for download.

## Installing Dependencies

If you don't have dependencies installed locally, you can use the
`INSTALL_DEPENDENCIES=true` variable to attempt auto-installation.

```bash
INSTALL_DEPENDENCIES=true ./ytranslate.sh [OPTIONS] <URL>
```

**Note:** Root (sudo) permissions are required for auto-installation.

---

### Переводите и скачивайте видео без усилий и ограничений

Этот скрипт позволяет легко переводить видео с YouTube и других онлайн-платформ.
Он использует [`vot-cli`](https://github.com/FOSWLY/vot-cli) для перевода, а
также утилиты командной строки [`ffmpeg`](https://ffmpeg.org/) и
[`yt-dlp`](https://github.com/yt-dlp/yt-dlp).

Главное преимущество — запуск в **Google Colab**, что позволяет
**скачивать видео на высокой скорости в обход замедления YouTube** со стороны
провайдеров.

Скрипт создает универсальные файлы (MKV + MP3/AVC), которые корректно
воспроизводятся на большинстве устройств, включая Chromecast, Android TV и Kodi.

## Возможности

* **Обход замедления YouTube**: Используйте версию для Google Colab, чтобы
  скачивать видео через серверы Google на максимальной скорости, игнорируя
  ограничения вашего провайдера.
* **Простой загрузчик видео**: Просто укажите одинаковые языки
  (например, с `ru` на `ru`), чтобы использовать скрипт как мощный инструмент
  для скачивания видео или плейлистов.
* **Автоматический перевод** видео с YouTube и других источников.
* **Интеграция со SponsorBlock**: Создает в MKV-файле главы для автоматического
  пропуска спонсорских сегментов (включено по умолчанию).
* **Интеграция с медиацентрами**: Автоматическое создание метаданных (`.nfo`)
  и обложек, идеально для Kodi, Jellyfin и Emby.
* **Высокая скорость**: Использование контейнера MKV и аудио MP3 позволяет
  избежать долгого перекодирования.
* **Поддержка плейлистов**: Возможность обработки целых плейлистов YouTube.
* **Синхронизация с YouTube**: Возможность помечать видео как "просмотренные"
  (нужны cookies).
* **Гибкая настройка**: Поддержка `.env` файлов, сохранение настроек (Colab)
  и множество флагов запуска.

## Использование

### Локально

1. Установите необходимые зависимости (ffmpeg, yt-dlp, vot-cli, npm/pip).
2. Сделайте [`ytranslate.sh`][script] исполняемым: `chmod +x ytranslate.sh`.
3. (Опционально) Создайте файл `.env` для сохранения настроек
   (например, `YT_TOLANG=ru`).
4. Запустите скрипт:

    ```bash
    ./ytranslate.sh [ОПЦИИ] <URL> [ЛОКАЛЬНЫЙ_ФАЙЛ]
    ```

    **Опции:**

    * `-h, --help`: Показать справку.
    * `-v, --version`: Показать версию скрипта.
    * `-r, --height=<int>`: Макс. высота видео (напр. 1080).
    * `-f, --from_lang=<str>`: Язык оригинала (по умолчанию: en).
    * `-t, --to_lang=<str>`: Язык перевода (по умолчанию: ru).
    * `-o, --output=<path>`: Папка для сохранения.
    * `-c, --cookies=<path>`: Путь к cookies (для приватных плейлистов или
      пометки "Просмотрено").
    * `-4, --ipv4`: Принудительно использовать IPv4.
    * `--force-avc`: Принудительно использовать кодек AVC (H.264) для
      старых устройств.
    * `--mark-watched`: Помечать видео как просмотренное на YouTube.
    * `--meta`: Создавать метаданные (.nfo и .jpg) для медиацентров.
    * `--no-sponsorblock`: Отключить разметку спонсорских сегментов
      (включено по умолчанию).
    * `--no-cleanup`: Не удалять временные файлы.

    **Примеры:**

    Перевод одного видео с созданием метаданных:

    ```bash
    ./ytranslate.sh -f en -t ru --meta https://youtu.be/VIDEO_ID
    ```

    Скачивание плейлиста на оригинальном языке с метаданными и пометкой
    "просмотрено":

    ```bash
    ./ytranslate.sh -f ru -t ru -c cookies.txt --meta --mark-watched \
      https://www.youtube.com/playlist?list=WL
    ```

### Запуск в Google Colab (Обход замедления)

1. Откройте файл [`ytranslate.ipynb`][notebook] в Google Colab.
2. Заполните параметры в блоке "Settings".
3. **Чтобы просто скачать видео**, укажите одинаковые языки в `FROMLANG`
   и `TOLANG`.
4. Запустите все ячейки.
5. Скрипт обработает видео и автоматически сохранит их на Google Drive или
   предложит скачать.

## Установка Зависимостей

Если зависимости не установлены, можно использовать переменную
`INSTALL_DEPENDENCIES=true` для их автоматической установки.

```bash
INSTALL_DEPENDENCIES=true ./ytranslate.sh [ОПЦИИ] <URL>
```

**Примечание:** Для автоматической установки требуются права суперпользователя
(root).

---

## Youtube

| [![google][google_img]][google_url] | [![linux][linux_img]][linux_url]
| --- | ---

[google_img]: https://img.youtube.com/vi/7-rYQ2QHXgo/0.jpg "Google Colab"
[google_url]: https://youtu.be/7-rYQ2QHXgo
[linux_img]: https://img.youtube.com/vi/gNvPf7nGXFQ/0.jpg "Linux"
[linux_url]: https://youtu.be/gNvPf7nGXFQ
[script]: https://raw.githubusercontent.com/alex2844/youtube-translate/v2.4.1/ytranslate.sh "Open script"
[notebook]: https://colab.research.google.com/github/alex2844/youtube-translate/blob/v2.4.1/ytranslate.ipynb "Open In Colab"
